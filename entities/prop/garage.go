embedded_components {
  id: "model"
  type: "model"
  data: "mesh: \"/assets/models/garage.glb\"\n"
  "name: \"garage\"\n"
  "materials {\n"
  "  name: \"default\"\n"
  "  material: \"/assets/materials/stylized3d.material\"\n"
  "  textures {\n"
  "    sampler: \"tex0\"\n"
  "    texture: \"/assets/images/palette_3d.png\"\n"
  "  }\n"
  "}\n"
  ""
  rotation {
    x: 0.70710677
    y: 0.0
    z: 0.0
    w: 0.70710677
  }
}
embedded_components {
  id: "label"
  type: "label"
  data: "size {\n"
  "  x: 600.0\n"
  "  y: 60.0\n"
  "}\n"
  "outline {\n"
  "  x: 0.106\n"
  "  y: 0.133\n"
  "  z: 0.22\n"
  "  w: 1.0\n"
  "}\n"
  "text: \"\"\n"
  "font: \"/assets/fonts/main.font\"\n"
  "material: \"/assets/materials/overlay_label.material\"\n"
  ""
  position {
    z: 1.15
  }
}
