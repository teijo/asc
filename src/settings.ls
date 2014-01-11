define ['util'], (util) ->

  settings =
    channel: 0
    dump: false
    max-energy: 10
    max-velocity: 1.5
    player:
      name: null
    server: ENV.serverAddress
    tickrate: 100
    state-throttle: 100
    window-dimensions: new THREE.Vector2!.fromArray [800, 600]
    acceleration:
      value: null
      base: 10
      step: 2
    turn:
      value: null
      base: util.deg-to-rad 90
      step: util.deg-to-rad 20
    shot-velocity:
      value: null
      base: 4.0
      step: 0.5
    shot-delay:
      value: null
      base: 10
      step: -3
    shot-range:
      value: null
      base: 600
      step: 100
    ship-size:
      value: null
      base: 15
      step: -4

  # Set base as default value
  map (-> if it is not null and typeof it is "object" then it.value = it.base; it), settings

  settings
