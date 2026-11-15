# City completion library

80 editable Blender assets: 48 modular additions and 32 assembled building variants across eight families. The variants reuse the established library geometry and original material slots; they are not 32 unrelated architectural styles.

Open `City_Completion_Library.blend`, select a mesh, and press Tab to edit it. Every asset has a base-oriented local mesh and an Asset Browser catalog entry under **City Completion**. Add this folder as a Blender Asset Library to browse it from other files. The gallery offsets do not travel with appended asset geometry when placed with the supplied map script.

| Kit | Assets |
| --- | ---: |
| Boats and fishing equipment | 8 |
| Bridge structure and connections | 6 |
| Retaining walls and drainage | 6 |
| Natural shoreline rocks | 6 |
| Quays and foundations | 6 |
| Farming and field boundaries | 10 |
| Architectural accessories | 6 |
| Merchant, apartment, warehouse, villa, farm, artisan, inn, boathouse variants | 32 |

`component_inventory.json` records dimensions, topology counts and source libraries. `building_variants.png` previews the assemblies. `validation.json` records mesh validity and Edit Mode checks.

Regenerate with Blender's background Python runner and `tools/build_city_completion_library.py`; validate with `tools/validate_city_completion.py`. These are stylized production blockout assets intended for further modeling polish.
