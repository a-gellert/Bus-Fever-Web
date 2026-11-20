embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"round\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/game.atlas\"\n"
  "}\n"
  ""
  position {
    z: 0
  }
}
embedded_components {
  id: "label"
  type: "label"
  data: "size {\n"
  "  x: 160.0\n"
  "  y: 48.0\n"
  "}\n"
  "color {\n"
  "  x: 0.12\n"
  "  y: 0.16\n"
  "  z: 0.22\n"
  "  w: 1.0\n"
  "}\n"
  "text: \"\"\n"
  "font: \"/builtins/fonts/default.font\"\n"
  "material: \"/builtins/fonts/label-df.material\"\n"
  ""
  position {
    z: 0.01
  }
}
