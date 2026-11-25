embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"round\"\n"
  "material: \"/assets/materials/hud_sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/assets/game.atlas\"\n"
  "}\n"
  ""
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
  "material: \"/assets/materials/hud_label.material\"\n"
  ""
  position {
    z: 0.01
  }
}
