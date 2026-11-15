#!/usr/bin/env python3
"""Read a local installation without executing its Lua or modifying the game.

Only generated Lua literals are accepted. The output retains selected facts,
source pointers, byte offsets and hashes, rather than copies of the game assets.
Optional native inspection uses Apple's existing nm and LLVM tools, not the game.
"""
import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess


TOKEN = re.compile(
    r"\s+|--[^\n]*|\[\[.*?\]\]|\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"
    r"|-?(?:0x[0-9a-fA-F]+|(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)"
    r"|[A-Za-z_]\w*|[{}\[\]=,;]", re.S
)


class LuaLiterals:
    def __init__(self, text):
        self.text = text
        self.tokens = []
        offset = 0
        while offset < len(text):
            match = TOKEN.match(text, offset)
            if not match:
                raise ValueError(f"Unsupported Lua syntax at character {offset}")
            token = match.group()
            if not token.isspace() and not token.startswith("--"):
                self.tokens.append((token, offset))
            offset = match.end()
        self.cursor = 0
        self.offsets = {}

    def peek(self, ahead=0):
        i = self.cursor + ahead
        return self.tokens[i][0] if i < len(self.tokens) else None

    def take(self, expected=None):
        if self.cursor >= len(self.tokens):
            raise ValueError("Unexpected end of Lua literal")
        token = self.tokens[self.cursor][0]
        if expected is not None and token != expected:
            raise ValueError(f"Expected {expected!r}, got {token!r}")
        self.cursor += 1
        return token

    def parse(self):
        root = self.take()
        self.take("=")
        value = self.value("/" + root)
        if self.peek() == ";":
            self.take()
        if self.peek() is not None:
            raise ValueError("Only a single literal assignment is supported")
        return root, value

    def value(self, pointer):
        self.offsets[pointer] = self.tokens[self.cursor][1]
        token = self.peek()
        if token == "{":
            self.take()
            fields, sequence = {}, []
            while self.peek() != "}":
                if self.peek(1) == "=":
                    key = self.take()
                    self.take("=")
                    fields[key] = self.value(pointer + "/" + str(key))
                elif self.peek() == "[" and self.peek(1) != "[":
                    self.take("[")
                    key = self.value(pointer + "/@key")
                    self.take("]")
                    self.take("=")
                    fields[str(key)] = self.value(pointer + "/" + str(key))
                else:
                    sequence.append(self.value(pointer + "/" + str(len(sequence))))
                if self.peek() in (",", ";"):
                    self.take()
                elif self.peek() != "}":
                    raise ValueError("Expected table separator")
            self.take("}")
            if fields and sequence:
                fields["@sequence"] = sequence
            return fields if fields else sequence
        token = self.take()
        if token.startswith("[["):
            return token[2:-2]
        if token[:1] in ("'", '"'):
            return ast.literal_eval(token)
        if token in ("true", "false", "nil"):
            return {"true": True, "false": False, "nil": None}[token]
        if re.fullmatch(r"-?0x[0-9a-fA-F]+", token):
            return int(token, 16)
        if re.fullmatch(r"-?\d+", token):
            return int(token)
        try:
            return float(token)
        except ValueError as exc:
            raise ValueError(f"Non-literal value: {token}") from exc


def walk(value, pointer):
    yield pointer, value
    items = value.items() if isinstance(value, dict) else enumerate(value) if isinstance(value, list) else []
    for key, child in items:
        yield from walk(child, pointer + "/" + str(key))


def identity(path):
    return {"bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def inspect_source(path, resources):
    if path.stat().st_size > 16 * 1024 * 1024:
        raise ValueError("Selected Lua file exceeds the 16 MiB read budget")
    text = path.read_text(encoding="utf-8")
    parser = LuaLiterals(text)
    root, data = parser.parse()
    result = {"path": str(path.relative_to(resources)), **identity(path), "root": root}

    def fact(pointer, value):
        offset = parser.offsets[pointer]
        return {"pointer": pointer, "byte_offset": len(text[:offset].encode("utf-8")), "value": value}

    if root == "BehaviourGraph":
        result["default_state"] = data.get("defaultstate")
        result["states"] = [
            {"name": state.get("name"), "tags": state.get("tags"),
             "behaviour": state.get("behaviour"), "transitions": state.get("transitions", []),
             "events": state.get("events", []), "source": fact(f"/{root}/states/{i}/name", state.get("name"))}
            for i, state in enumerate(data.get("states", []))
        ]
        result["events"] = data.get("events", [])
    elif root == "Attributes":
        relevant = re.compile(r"(vision|sight|hear|forget|interest|squad|prox|notice|targetpriority|pathcaps|hidingspot|light|canbelit|skins|exposed|noise|sound|projectiles)", re.I)
        result["components"] = []
        for i, component in enumerate(data.get("components", [])):
            selected = {key: fact(f"/{root}/components/{i}/{key}", value)
                        for key, value in component.items() if relevant.search(key)}
            if selected:
                result["components"].append({"componenttype": component.get("componenttype"), "fields": selected})
    else:
        result["action_type_counts"] = Counter(
            node["Type"] for _, node in walk(data, "/" + root) if isinstance(node, dict) and "Type" in node
        )
        matches = []
        for pointer, node in walk(data, "/" + root):
            if not isinstance(node, dict):
                continue
            for key, value in node.items():
                if re.search(r"audibleradius|soundradius|litstate|lightstate|detectmovement", key, re.I):
                    matches.append({**fact(pointer + "/" + key, value),
                                    "action_type": node.get("Type"), "action_event": node.get("event"),
                                    "debug": node.get("debuginfo")})
        result["sensory_fields"] = matches
        result["common_actions"] = []
        selected_actions = {"run_loud_noise", "run_normal_noise", "walk_normal_noise",
                            "noisemaker_noise", "prop_noise_bell_0_1"}
        for i, action in enumerate(data.get("CommonActions", [])):
            if action.get("name") not in selected_actions:
                continue
            actions = []
            for pointer, node in walk(action, f"/{root}/CommonActions/{i}"):
                if isinstance(node, dict) and node.get("Type") in ("addinterestsource", "SpawnFX"):
                    fields = {key: value for key, value in node.items()
                              if key in ("Type", "sense", "source", "radius", "maxdistance", "ttl",
                                         "priority", "followowner", "forgetlosttarget", "fx")}
                    actions.append(fact(pointer, fields))
            result["common_actions"].append({"name": action["name"],
                                            "debug": action.get("debuginfo"), "actions": actions})
        result["selected_state_links"] = []
        for i, state in enumerate(data.get("States", [])):
            if "noisemaker" not in path.name and not set(str(state.get("tags", "")).split()).intersection({"hiding", "peeking"}):
                continue
            references = [fact(pointer + "/name", node.get("name"))
                          for pointer, node in walk(state, f"/{root}/States/{i}")
                          if isinstance(node, dict) and node.get("Type") == "docommonaction"]
            edges = [{"event": event.get("event"),
                      "destinations": [edge.get("dest") for edge in event.get("transitions", [])]}
                     for event in state.get("events", []) if event.get("transitions")]
            result["selected_state_links"].append({"name": state.get("name"), "tags": state.get("tags"),
                                                   "debug": state.get("debuginfo"), "calls": references,
                                                   "events": edges})
    return result


def native_report(binary):
    symbols = subprocess.check_output(["nm", "-n", str(binary)], text=True)
    rows = []
    for line in symbols.splitlines():
        parts = line.split(maxsplit=2)
        if len(parts) == 3 and re.fullmatch(r"[0-9a-fA-F]+", parts[0]):
            rows.append((int(parts[0], 16), parts[1], parts[2]))
    targets = ("12CanHearSound", "21HasLineOfSightToSound", "14HasPathToSound",
               "18TargetIsDetectable", "15SearchBehaviour20GenerateSearchPoints")
    functions = []
    for i, (address, kind, name) in enumerate(rows[:-1]):
        if kind.lower() != "t" or not any(target in name for target in targets):
            continue
        end = rows[i + 1][0]
        if not 0 < end - address <= 16384:
            continue
        assembly = subprocess.check_output([
            "xcrun", "llvm-objdump", "--disassemble", "--demangle",
            f"--start-address={address}", f"--stop-address={end}", str(binary)
        ], text=True)
        calls = [(at, symbol) for at, symbol in re.findall(r"calll?\s+0x([0-9a-f]+)\s+<([^\n]+)>", assembly)
                 if not address <= int(at, 16) < end]  # Exclude x86 PIC call/pop sequences.
        functions.append({"symbol": name, "address": hex(address), "end_exclusive": hex(end),
                          "disassembly_sha256": hashlib.sha256(assembly.encode()).hexdigest(),
                          "calls": [{"address": "0x" + at, "symbol": symbol} for at, symbol in calls]})
    return {"method": "Apple nm and xcrun llvm-objdump; no game execution", "functions": functions}


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument("--app", type=Path, default=Path.home() / "Library/Application Support/Steam/steamapps/common/mark_of_the_ninja/ninja.app")
    cli.add_argument("--output", type=Path, required=True)
    cli.add_argument("--native", action="store_true", help="Use installed Apple tools for bounded native call inventories")
    cli.add_argument("--rea-evidence", type=Path, help="Retain provenance and coverage of an existing REA artifact report")
    args = cli.parse_args()
    resources = args.app / "Contents/Resources"
    binary = args.app / "Contents/MacOS/ninja"
    lua_files = list(resources.rglob("*.lua"))
    selected = [
        "data/attributes/med_guard_rifle.lua", "data/attributes/guard_dog.lua",
        "data/attributes/ninja.lua", "data/attributes/projectile_noisemaker.lua",
        "data/behaviourgraphs/patroller.lua", "data/behaviourgraphs/guard_dog.lua",
        "data/stategraphs/ninja.lua", "data/stategraphs/projectile_noisemaker.lua",
        "data/stategraphs/hiding_spot.lua",
    ]
    report = {
        "scope": "Bounded static inspection; Lua parsed as literals, never executed; no gameplay observations",
        "app": str(args.app), "binary": {**identity(binary), "header_hex": binary.read_bytes()[:12].hex()},
        "inventory": {"lua_files": len(lua_files), "lua_bytes": sum(p.stat().st_size for p in lua_files)},
        "sources": [inspect_source(resources / relative, resources) for relative in selected],
        "limitations": ["Selected configuration defaults can be overridden by levels or runtime state.",
                        "Distances and angles retain source units; these are not Godot tuning values.",
                        "Native calls verify relationships, not complete algorithms or runtime reachability.",
                        "No game artwork, audio, or full source files are copied into the project."]
    }
    header = struct.unpack("<III", binary.read_bytes()[:12])
    report["binary"]["format"] = "Mach-O 32-bit i386" if header[0] == 0xFEEDFACE and header[1] == 7 else "unclassified"
    if args.native:
        report["native"] = native_report(binary)
    if args.rea_evidence:
        rea = json.loads(args.rea_evidence.read_text())
        report["rea"] = {key: rea.get(key) for key in
                         ("evidence_id", "subject", "provider", "operation", "confidence", "authority", "limitations")}
        report["rea"]["report_sha256"] = identity(args.rea_evidence)["sha256"]
        report["rea"]["coverage"] = rea.get("normalized_result", {}).get("coverage")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"output": str(args.output), "lua_files": len(lua_files),
                      "sources_inspected": len(report["sources"]),
                      "native_functions": len(report.get("native", {}).get("functions", []))}))


if __name__ == "__main__":
    main()
