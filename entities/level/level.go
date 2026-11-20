components {
  id: "level"
  component: "/entities/level/level.script"
}
embedded_components {
  id: "bus_factory"
  type: "collectionfactory"
  data: "prototype: \"/entities/bus/bus.collection\"\n"
  ""
}
embedded_components {
  id: "tile_factory"
  type: "factory"
  data: "prototype: \"/entities/tile/tile.go\"\n"
  ""
}
embedded_components {
  id: "passenger_factory"
  type: "factory"
  data: "prototype: \"/entities/passenger/passenger.go\"\n"
  ""
}
embedded_components {
  id: "panel_factory"
  type: "factory"
  data: "prototype: \"/entities/panel/panel.go\"\n"
  ""
}
