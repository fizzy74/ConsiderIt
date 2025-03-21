
#######################
# Customizations.coffee
#
# Tailor considerit applications by subdomain

window.customizations = {}
customizations_by_file = {}

window._ = _


#######
# API
#
# The customization method returns the proper value of the field for this 
# subdomain, or the default value if it hasn't been defined for the subdomain.
#
# object_or_key is optional. If passed, customization will additionally check for 
# special configs for that object (object.key) or key.



# Either stringify functions or convert them to functions. 
# Will toggle -- it recurses down obj and finds a stringified
# function, it will return an actual function. If it encounters
# a function, it will stringify it. 
window.FUNCTION_IDENTIFIER = "#javascript\n"
convert_customization = (obj) ->  
  __convert obj, []

__convert = (obj, path) ->
  if Array.isArray(obj)
    return (__convert(vv, path) for vv in obj)
  else if obj == null 
    return null
  else if typeof(obj) == 'object' 
    tree = {}
    for k,v of obj
      p = path.slice()
      p.push k
      tree[k] = __convert(v,p)
    return tree

  else if typeof(obj) == 'function'
    return "#{FUNCTION_IDENTIFIER}#{obj.toString()}"

  else if typeof(obj) == 'string' && obj.startsWith(FUNCTION_IDENTIFIER)
    str_func = obj.substring FUNCTION_IDENTIFIER.length
    func = new Function("return #{str_func}")()
    return func

  else 
    return obj




window.load_customization = (subdomain) ->
  return if !subdomain.name
  subdomain_name = subdomain.name?.toLowerCase()

  try 
    customizations_file_used = !!customizations_by_file[subdomain_name]
    if customizations_file_used
      console.log "#{subdomain_name} config for import: \n", JSON.stringify(convert_customization(customizations_by_file[subdomain_name]), null, 2)

    subdomain = bus_fetch '/subdomain'

    customizations[subdomain_name] = _.extend {}, (customizations_by_file[subdomain_name] or {}), convert_customization(subdomain.customizations)

  catch error 
    console.error error


window.customization = (field, object_or_key, subdomain) -> 
  
  if !!object_or_key && !object_or_key.key?
    obj = bus_fetch object_or_key
  else 
    obj = object_or_key

  if !subdomain?
    if object_or_key?.key?.match('/subdomain/')
      subdomain = object_or_key
    else 
      subdomain = bus_fetch('/subdomain')
      if obj?.subdomain_id? && obj.subdomain_id != subdomain.id 
        subdomain = bus_fetch "/subdomain/#{obj.subdomain_id}" 

  subdomain_name = subdomain.name?.toLowerCase()
  
  key = if obj 
          if obj.key then obj.key else obj
        else 
          null

  ########
  # The chain of customizations: 
  #  1) any object-specific configuration
  #  2) subdomain configuration
  #  3) global default configuration

  chain_of_configs = []

  if customizations[subdomain_name]?

    subdomain_config = customizations[subdomain_name]

    # object-specific config
    if key 

      if subdomain_config[key]?
        chain_of_configs.push subdomain_config[key]

      # list-level config for proposals
      if key.match(/\/proposal\//)
        proposal = obj
        list_key = get_list_for_proposal(proposal)
        if subdomain_config[list_key]?
          chain_of_configs.push subdomain_config[list_key]

    # subdomain config
    chain_of_configs.push subdomain_config
  
  # global default config
  chain_of_configs.push customizations['default']

  value = undefined
  for config in chain_of_configs
    value = config[field]

    break if value?

  # if !value?
  #   console.error "Could not find a value for #{field} #{if key then key else ''}"

  value



window.CustomizationTransition = ReactiveComponent
  displayName: 'CustomizationTransition'
  # This doesn't actually render anything.  It just notices when the customizations
  # field of subdomain has changed and marks it dirty.

  render: -> 
    subdomain = bus_fetch('/subdomain')
    customizations_signature = bus_fetch('customizations_signature')

    check_update_customizations_object = -> 
      signature = JSON.stringify(subdomain.customizations)

      if customizations_signature.signature != signature 
        customizations_signature.signature = signature
        load_customization subdomain
        save customizations_signature
        re_render(['/subdomain']) # rerender all the components that depend on /subdomain, without saving it to the server

    # we need to wait for the server to return if there is still a pending /subdomain save otherwise weird stuff happens
    ck = setInterval ->
      if !arest.pending_saves['/subdomain']
        check_update_customizations_object()
        clearInterval ck

    , 1


    SPAN null



# require './color'
# require './logo'
# require './shared'

require './browser_location' # for loadPage
require './slider'
require './customizations_helpers'





################################
# DEFAULT CUSTOMIZATIONS


customizations.default = 

  point_labels : point_labels.pro_con
  slider_pole_labels : slider_labels.agree_disagree
  list_opinions_title: 'Opinions'
  list_items_title: 'Proposals'

  # Proposal options
  discussion_enabled: true

  homepage_show_search_and_sort: true

  list_permit_new_items: true
  homepage_show_new_proposal_button: true

  show_proposal_meta_data: true 

  slider_handle: slider_handle.flat
  slider_regions: null

  show_proposal_scores: true

  show_proposer_icon: true
  collapse_proposal_description_at: 300

  # default list options
  list_is_archived: false
  list_uncollapseable: false
  list_item_name: 'Proposal'

  # Other options
  auth_footer: false
  has_homepage: true

  auth_callout: true

  user_tags: {}


  # IBM Plex Sans
  # Trebuchet MS, palantino, and optima are intriguing web-safe fonts
  font: "IBM Plex Sans, Helvetica Neue, sans-serif"
  header_font: "IBM Plex Sans, IBM Plex Sans, Helvetica Neue, sans-serif"
  condensed_font: "IBM Plex Sans Condensed, IBM Plex Sans, Helvetica Neue, sans-serif"
  mono_font: "IBM Plex Mono, Menlo, Consolas, Monaco, Fira Mono, Liberation Mono, Lucida Console, monospace"

  new_proposal_fields: -> 
   name:  translator("engage.edit_proposal.summary_label", "Summary")
   description: translator("engage.edit_proposal.description_label", "Details") + " (#{translator('optional', 'optional')})" 
   additional_fields: []
   create_description: (fields) -> fields.description



##########################
# SUBDOMAIN CONFIGURATIONS


text_and_masthead = ['educacion2025', 'ynpn', 'lsfyl', 'kealaiwikuamoo', 'iwikuamoo']
masthead_only = ["kamakakoi","seattletimes","kevin","ihub","SilverLakeNC",\
                 "Relief-Demo","GS-Demo","ri","ITFeedback","Committee-Meeting","policyninja", \
                 "SocialSecurityWorks","amberoon","economist","impacthub-demo","mos","Cattaca", \
                 "Airbdsm","bitcoin-ukraine","lyftoff","hcao","arlingtoncountyfair","progressive", \
                 "design","crm","safenetwork","librofm","washingtonpost","MSNBC", \
                 "PublicForum","AMA-RFS","AmySchumer","VillaGB","AwesomeHenri", \
                 "citySENS","alcala","MovilidadCDMX","deus_ex","neuwrite","bitesizebio","HowScienceIsMade","SABF", \
                 "engagedpublic","sabfteam","Tunisia","theartofco","SGU","radiolab","ThisLand", \
                 "Actuality", 'cimsec', 'sosh', 'swotconsultants']


setTimeout ->
  if ImageHeader?
    # The old image banner + optional text description below
    window.LegacyImageHeader = ImageHeader

    for sub in text_and_masthead
      customizations_by_file[sub.toLowerCase()] = 
        HomepageHeader: LegacyImageHeader

    for sub in masthead_only
      customizations_by_file[sub.toLowerCase()] = 
        HomepageHeader: LegacyImageHeader




