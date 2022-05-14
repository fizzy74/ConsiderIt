# Unfortunately, google makes it so there can only be one Google Translate Widget 
# rendered into a page. So we have to move around the same element, rather than 
# embed it nicely where we want. 

styles += """
  .google-translate-candidate-container {
    width: 158px;
    height: 25px;
  }
"""
window.GoogleTranslate = ReactiveComponent
  displayName: 'GoogleTranslate'

  render: -> 
    loc = fetch 'location'
    homepage = loc.url == '/'

    return SPAN null if embedded_demo()

    style = if customization('google_translate_style') && homepage 
              s = JSON.parse JSON.stringify customization('google_translate_style')
              delete s.prominent if s.prominent
              delete s.callout if s.callout
              s
            else 
              _.defaults {}, @props.style, 
                textAlign: 'center'
                marginBottom: 10

    DIV 
      style: 
        position: 'absolute'
        left: @local.left 
        top: @local.top
        zIndex: 9
           
      DIV 
        key: "google_translate_element_#{@local.key}"
        id: "google_translate_element_#{@local.key}"
        style: style

  insertTranslationWidget: -> 
    subdomain = fetch '/subdomain'


    new google.translate.TranslateElement {
        pageLanguage: subdomain.lang
        layout: google.translate.TranslateElement.InlineLayout.SIMPLE
        multilanguagePage: true
        # gaTrack: #{Rails.env.production?}
        # gaId: 'UA-55365750-2'
      }, "google_translate_element_#{@local.key}"

  componentDidMount: -> 

    @int = setInterval => 
      if google?.translate?.TranslateElement?
        @insertTranslationWidget()
        clearInterval @int 
    , 20

    # location of this element will shadow the position of the first instance
    # of an element with a class of google-translate-candidate-container
    @placer_int = setInterval =>
      wrapper = document.querySelector '.google-translate-candidate-container'
      return if !wrapper
      coords = getCoords(wrapper)
      if coords.left != @local.left || coords.top != @local.top
        @local.left = coords.left
        @local.top = coords.top
        save @local
    , 100

  componentWillUnmount: ->
    clearInterval @int
    clearInterval @placer_int