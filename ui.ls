calculate-score = !->
  total = 0
  for i in $ \.slider
    total -= parseInt($(i).val())
  $ "h2 span" .text if total > 0 then "+"+total else total

SLIDER =
  from: -3
  to: 3
  step: 1
  scale: [\-3, \-2, \-1, \0, \+1, \+2, \+3]
  smooth: false
  dimension: ''
  skin: "yellow"
  calculate: (value) ->
    if value > 0 then "+"+value else value
  callback: ->
    $ this.inputNode .trigger \change
    setup = {}
    for i in $ \.slider
      setup[$(i).attr \name] = i.value
    $.cookies.set \setup, setup
    calculate-score!

$ ->
  SETTINGS = exports.SETTINGS
  INPUT = exports.INPUT

  inputs = [
    {
      label: "Acceleration"
      name: "acceleration"
      setting: SETTINGS.acceleration
    }, {
      label: "Rate of fire"
      name: "fire-delay"
      setting: SETTINGS.shot-delay
    }, {
      label: "Projectile speed"
      name: "projectile-speed"
      setting: SETTINGS.shot-velocity
    }, {
      label: "Projectile range"
      name: "projectile-range"
      setting: SETTINGS.shot-range
    }, {
      label: "Size"
      name: "size"
      setting: SETTINGS.ship-size
    }, {
      label: "Turning speed"
      name: "turn"
      setting: SETTINGS.turn
    }
  ]
  fieldset = $ \fieldset
  setup = $.cookies.get \setup
  name = $ \<input>
  name.val if setup is not null and setup[\name] is not undefined then setup[\name] else \Name
  name.attr \name \name
  SETTINGS.player.name = name.val!
  nameUpdates = name.asEventStream \keyup .onValue (event) ->
    setup = $.cookies.get \setup
    setup[\name] = SETTINGS.player.name = $ event.target .val!
    $.cookies.set \setup setup
  p = $ \<p>
  p.text \Name
  fieldset.append p
  fieldset.append name

  nameUpdates = $ \#channel .asEventStream \change .onValue (event) ->
    INPUT.change-channel parseInt($ event.target .val!)
    $("[name=spawn]").removeAttr(\disabled)

  for input in inputs
    i = $ \<input>
    i.attr \class \slider
    i.change input, (event) ->
      setting = event.data.setting;
      setting.value = setting.base + this.value * setting.step
    p = $ \<p>
    p.text input.label
    i.attr \name, input.name
    value = if setup != null then setup[input.name] else null
    if value != null and value != undefined
      i.val value
    else
      i.val 0
    fieldset.append p
    fieldset.append i

  $input = $("input.slider")
  $input.slider(SLIDER)
  h2 = $ \<h2>
  h2.html "Handicap: <span>0</span>"
  fieldset.append h2
  spawn = $('<input type="submit" name="spawn" value="&gt;&gt;&gt; Spawn &lt;&lt;&lt;" />')
  spawn.click (event) ->
    $(this).attr \disabled, \disabled
    INPUT.spawn!
  fieldset.append spawn
  calculate-score!
