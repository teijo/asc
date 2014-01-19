prelude.installPrelude window

requirejs.config {baseUrl: '.'}

requirejs ['state', 'util', 'ui', 'draw', 'net', 'settings', 'tick', 'input'], (st, util, ui, draw, network, settings, tick, input)->
  adjust-canvas-size = ! ->
    $ "canvas"
      ..attr \width window.innerWidth
      ..attr \height window.innerHeight

  bindPointer = (canvas) ->
    if input.is-touch
      start = Bacon.fromEventTarget(canvas, 'touchstart')
      Bacon.fromEventTarget(canvas, 'touchmove').merge(start).map (ev) ->
        ev.preventDefault!
        touch = ev.touches[0]
        x: touch.screenX
        y: touch.screenY
    else
      Bacon.fromEventTarget(canvas, 'mousemove').map (ev) ->
        x: ev.x
        y: ev.y

  bindClickState = (canvas) ->
    if input.is-touch
      downs = Bacon.fromEventTarget(canvas, 'touchstart').map(true)
      ups = Bacon.fromEventTarget(canvas, 'touchend').map(false)
      downs.merge(ups).toProperty(false).changes()
    else
      downs = Bacon.fromEventTarget(canvas, 'mousedown').map(true)
      ups = Bacon.fromEventTarget(canvas, 'mouseup').map(false)
      downs.merge(ups).toProperty(false).changes()

  bindKeys = ->
    Bacon.fromEventTarget(window, 'resize').throttle(100).onValue adjust-canvas-size
    concat = (a1, a2) -> a1.concat a2
    ups = $ document .asEventStream \keyup
    downs = $ document .asEventStream \keydown
    always = (value) -> ((_) -> value)
    select = (key, stream) -> (stream.filter (.keyCode == key.code))
    state = (key) -> select(key, downs) \
      .map(always([key])) \
      .merge(select(key, ups).map(always([]))) \
      .toProperty([])
    state(input.key.up)
      .combine state(input.key.down), concat
      .combine state(input.key.left), concat
      .combine state(input.key.right), concat
      .combine state(input.key.space), concat
      .combine state(input.key.esc), concat

  tick-delta = util.delta-timer!
  setInterval (-> tick tick-delta!; st.tick++), 1000 / settings.tickrate
  bindKeys!.onValue (keys-down) -> st.input := keys-down

  canvas = document.getElementsByTagName('canvas')[0]
  bindPointer(canvas).onValue ->
    st.pointer.x = it.x
    st.pointer.y = it.y
  bindClickState(canvas).onValue ->
    st.click-state = it
