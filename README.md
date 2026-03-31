# godot-sdfmeshgen

An interactive SDF (Signed Distance Field) editor built in Godot 4.0. It uses GPU compute shaders to render and compose 3D shapes in real time through boolean operations. Users can sculpt complex geometry by placing, combining, and subtracting SDF primitives in a 3D viewport with smooth blending support.

## How to Run

1. Install [Godot 4.0](https://godotengine.org/download/) (Forward Plus rendering backend required).
2. Clone this repository and open the project in Godot.
3. Run the project — the main scene (`Editor.tscn`) launches automatically.

There are no external build steps, dependencies, or test suites. The project runs entirely within the Godot editor.

## Usage

- **Hold RMB** to enter FPS camera mode (WASD to move, Space/Ctrl for up/down, Shift to sprint).
- **Scroll wheel** to adjust the cursor/shape size.
- Select a primitive (Sphere or Cube) from the right panel.
- Press **C** to create a shape at the cursor, **X** to subtract.
- Press **Escape** to cancel the current tool.
- Use the **color picker** and **blending slider** on the left panel to control shape color and smooth blending amount.

## Features

- **Real-time SDF rendering** via GLSL compute shaders on the GPU.
- **SDF primitives**: sphere, box, ellipsoid, round cone, and quadratic Bézier curve.
- **Boolean operations**: union, subtraction, and intersection, each with smooth variants for organic blending.
- **Transformations**: translation, rotation, and per-shape color assignment.
- **3D cursor** with depth and normal feedback from the compute shader.
- **Object picking** using per-pixel object ID output from the shader.
- **Scene outline** panel listing all placed objects.
- **Adaptive resolution**: renders at half resolution during camera movement for responsive interaction, then full resolution when stationary.

## Limitations

- Godot 4.0 with Forward Plus rendering is required; no support for other backends.
- No mesh export — shapes exist only as SDF programs and cannot be saved to standard mesh formats.
- No undo/redo system.
- No project save/load functionality.
- The set of primitives is fixed and cannot be extended without modifying the compute shader.
- Editor UI is minimal and not fully polished (e.g., the box widget was experimental).

## History

Development started on 2023-04-25 and largely stopped on 2023-06-03:

- **2023-04-25** — Initial commit with SDF sphere rendering via compute shader, basic editor scene, and FPS camera controller.
- **2023-04-29** — Added interactive shape creation and deletion with a 3D cursor, ghost material preview, and scroll-wheel size control.
- **2023-05-27** — Added multiple SDF primitives (box, ellipsoid, round cone, quadratic Bézier), a primitive picker UI, smooth boolean operations, and a color slider shader.
- **2023-05-27** — Introduced axis handle and box transform widgets, a scene outline panel, and a widget testbed scene.
- **2023-06-01** — Worked on box widget interaction; fixed broken box widget reference.
- **2023-06-03** — Shader refactoring: separated depth and surface map calculations, added an explicit surface struct, and introduced per-pixel object ID output for object picking.

## License

[MIT](LICENSE) © 2023 Stephen Molyneaux
