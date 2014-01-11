define ['util', 'state', 'settings'], (util, state, settings) ->
  SPAWN =
    player: settings.player
    velocity: new THREE.Vector2!.copy util.ZERO2
    heading: new THREE.Vector2!.fromArray [0, -1]
    position: settings.window-dimensions.clone!.multiplyScalar 0.5
    shots: []
    shot-tick: 0
    diameter: settings.ship-size
    energy: settings.max-energy

  spawn: ->
    if state.ships.length == 0 or state.ships[0].id is not void
      state.ships = [^^SPAWN] ++ state.ships
      state.input-dirty = true
    else
      throw "Must not try to spawn duplicates"
  change-channel: (new-channel, ready-cb) ->
    settings.channel = new-channel
    state.queue.push(id: \DEAD, data: { by: 0 })
    state.ships = []
    state.input-dirty = true
  key:
    up:
      code: 38
    space:
      code: 32
    down:
      code: 40
    left:
      code: 37
    right:
      code: 39
    esc:
      code: 27
