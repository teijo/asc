SETTINGS = exports.SETTINGS

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
    total = 0
    for i in $ \input
      total -= parseInt($(i).val())
    $ "h2 span" .text if total > 0 then "+"+total else total

$ ->
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

  for input in inputs
    i = $ \<input>
    i.change input, (event) ->
      setting = event.data.setting;
      setting.value = setting.base + this.value * setting.step
    p = $ \<p>
    p.text input.label
    i.name = input.name
    i.val 0
    fieldset.append p
    fieldset.append i

  $input = $("input")
  $input.slider(SLIDER)
  h2 = $ \<h2>
  h2.html "Handicap: <span>0</span>"
  fieldset.append h2
