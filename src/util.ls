define {
  PI2: Math.PI*2
  ZERO2: new THREE.Vector2 0, 0
  deg-to-rad: (degrees) ->
    degrees / 360 * @PI2
  log: !(msg) -> console.log msg
  time-scale: (delta-ms) ->
    (per-second) ->
      per-second * (delta-ms / 1000)
}
