require './shared'
require './customizations'



save 
  key: 'opinion_views'
  active_views: {}

save
  key: 'opinion_views_ui'
  active: "All opinions"
  visible_attributes: {}
  selected_vals_for_attribute: {}


window.compose_opinion_views = (opinions, proposal, opinion_views) -> 
  opinion_views ?= fetch('opinion_views')
  opinion_views.active_views ?= {}
  active_views = opinion_views.active_views

  if !opinions
    opinions = opinionsForProposal(proposal)

  weights = {}
  salience = {}
  groups = {}

  has_groups = false
  for view_name, view of active_views
    has_groups ||= view.get_group?

  for o in opinions
    weight = 1
    min_salience = 1

    if has_groups
      u_groups = []

    u = o.user.key or o.user

    for view_name, view of active_views
      if view.get_salience?
        s = view.get_salience(u, o, proposal)
        if s < min_salience
          min_salience = s
      if view.get_weight?
        weight *= view.get_weight(u, o, proposal)
      if has_groups && view.get_group?
        ggg = view.get_group(u, o, proposal)
        if Array.isArray(ggg)
          u_groups = u_groups.concat ggg
        else 
          u_groups.push ggg
    weights[u] = weight
    salience[u] = min_salience
    if has_groups      
      groups[u] = u_groups

  {weights, salience, groups}
  

window.get_opinions_for_proposal = (opinions, proposal, weights) ->
  if !opinions
    opinions = opinionsForProposal proposal
  if !weights
    {weights, salience, groups} = compose_opinion_views(opinions, proposal)

  (o for o in opinions when weights[o.user] > 0)


# Attributes are data about participants that can serve as additional filters. 
# We take them from legacy opinion views, and from 
# qualifying user_tags
window.get_participant_attributes = -> 
  attributes = [] 
  is_admin = fetch('/current_user').is_admin
  show_others = (!customization('hide_opinions') || is_admin) && !customization('anonymize_everything')
  custom_filters = customization 'opinion_views'
  user_tags = customization 'user_tags'

  if show_others
    if custom_filters
      for filter in custom_filters
        if filter.visibility == 'open' || is_admin
          if filter.pass
            attributes.push _.extend {}, filter, 
              key: filter.label
              name: filter.label
              options: ['true', 'false']

    if user_tags
      for tag in user_tags 
        name = tag.key
        if (tag.visibility == 'open' || is_admin) && \
           (tag.self_report?.input in ['dropdown', 'boolean', 'checklist']) && \
           !tag.no_opinion_view # set in the user_tags customization to prevent an opinion view from automatically getting created

          attributes.push 
            key: name
            name: tag.view_name or tag.name or tag.self_report?.question or name
            pass: do(name) -> (u, value) -> 
              if value?
                fetch(u).tags[name] == value
              else 
                fetch(u).tags[name]
            options: tag.self_report.options or (if tag.self_report.input == 'boolean' then [true, false])
            input_type: tag.self_report?.input

  attributes




window.get_user_groups_from_views = (groups) ->
  has_groups = Object.keys(groups).length > 0
  if has_groups
    group_set = new Set()
    for u, u_groups of groups
      for g in u_groups 
        group_set.add g
    Array.from group_set
  else 
    null 

window.group_colors = {}
window.get_color_for_groups = (group_array) ->
  if 'Unreported' not in group_array
    group_array = group_array.slice()
    group_array.push 'Unreported'
  colors = getColors(group_array.length)

  for color,idx in colors 
    if group_array[idx] not of group_colors
      if group_array[idx] == 'Unreported'
        color = 'black'
      group_colors[group_array[idx]] = color
  group_colors

window.get_color_for_group = (val) ->
  group_colors[val]


  # num_groups = group_array.length
  # hues = getNiceRandomHues num_groups
  # colors = group_colors
  # for hue,idx in hues 
  #   if group_array[idx] not of group_colors
  #     group_colors[group_array[idx]] = hsv2rgb hue, Math.random() / 2 + .5, Math.random() / 2 + .5
  # group_colors






default_filters = 
  everyone: 
    key: 'everyone'
    name: 'everyone'
    pass: (u) -> true 

  just_you: 
    key: 'just_you'
    name: 'Just you'
    pass: (u) -> 
      user = fetch(u)
      user.key == fetch('/current_user').user

  by_date: 
    key: 'date'
    name: 'By date'
    pass: (u) ->
      true
    options: ['Today', 'Past week', 'Custom']


window.influence_network = {}
window.influencer_scores = {}
influencer_scores_initialized = false 
add_influence = (influenced, influencer, amount) ->
  amount ?= 1
  influence_network[influenced] ?=
    influenced_by: {}
    influenced: {}
  influence_network[influencer] ?=
    influenced_by: {}
    influenced: {}

  influence_network[influencer].influenced[influenced] ?= 0
  influence_network[influencer].influenced[influenced] += amount

  influence_network[influenced].influenced_by[influencer] ?= 0
  influence_network[influenced].influenced_by[influencer] += amount


build_influencer_network = ->
  proposals = fetch '/proposals'
  points = fetch '/points'

  if !points.points || !proposals.proposals 
    return

  for point in points.points
    for user in point.includers or []
      continue if (user.key or user) == point.user
      add_influence user, point.user


  for proposal in proposals.proposals 
    opinions = opinionsForProposal proposal
    for opinion in opinions  
      continue if opinion.stance < 0.1

      add_influence opinion.user, proposal.user, opinion.stance

  max_influence = 0 
  for user, influence of influence_network
    num_influenced = Object.keys(influence.influenced).length
    total_influence = 0
    for u, amount of influence.influenced
      total_influence += amount
    influence = Math.log(2 + num_influenced + total_influence)
    if num_influenced + total_influence > max_influence
      max_influence = influence

    influencer_scores[user] = influence

  for user, influence of influence_network
    influencer_scores[user] /= max_influence # Math.sqrt(max_influence)



  influencer_scores_initialized = true



default_weights = 

  weighed_by_substantiated: 
    key: 'weighed_by_substantiated'
    name: 'Reasons given'
    label: 'Add weight to opinions that explained their stance with pro and/or con reasons.'
    weight: (u, opinion, proposal) ->
      point_inclusions = Math.log(1 + Math.min(8,opinion.point_inclusions?.length or 0))
      .1 + point_inclusions
    icon: (color) -> 
      color ?= 'black'
      SVG
        width: 14
        height: 14
        viewBox: "0 0 23 23"
        dangerouslySetInnerHTML: __html: """
          <g id="Group-8" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
              <polygon id="Rectangle" stroke="#{color}" points="0 0 23 0 23 17.8367347 11.5 17.8367347 6.41522296 23 6.41522296 17.8367347 0 17.8367347"></polygon>
              <ellipse id="Oval" fill="#{color}" cx="4.66666683" cy="8.43750016" rx="1.5333335" ry="1.43750016"></ellipse>
              <line stroke="#{color}" x1="8.37575758" y1="8.5" x2="17.7575758" y2="8.5" id="Line-5" stroke="#979797" stroke-linecap="square"></line>
              <ellipse id="Oval" fill="#{color}" cx="4.66666683" cy="3.43750016" rx="1.5333335" ry="1.43750016"></ellipse>
              <line stroke="#{color}" x1="8.37575758" y1="3.5" x2="17.7575758" y2="3.5" id="Line-5" stroke="#979797" stroke-linecap="square"></line>
              <ellipse id="Oval" fill="#{color}" cx="4.66666683" cy="13.4375002" rx="1.5333335" ry="1.43750016"></ellipse>
              <line stroke="#{color}" x1="8.37575758" y1="13.5" x2="17.7575758" y2="13.5" id="Line-5" stroke="#979797" stroke-linecap="square"></line>
          </g>
        """    

  weighed_by_deliberative: 
    key: 'weighed_by_deliberative'
    name: 'Tradeoffs recognized'
    label: 'Add weight to opinions that acknowledge both pro and con tradeoffs.'
    weight: (u, opinion, proposal) ->
      point_inclusions = opinion.point_inclusions
      pros = 0 
      cons = 0  
      for inc in point_inclusions or []
        pnt = fetch(inc)
        if pnt.is_pro 
          pros += 1
        else 
          cons += 1

      tradeoffs_recognized = Math.min pros, cons 

      if tradeoffs_recognized > 0
        1 + Math.log tradeoffs_recognized
      else 
        .1
    icon: (color) -> 
      color ?= 'black'
      SVG
        width: 14
        height: 14
        viewBox: "0 0 23 23"
        dangerouslySetInnerHTML: __html: """
          <g id="weigh" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
              <path fill="#{color}" d="M22.9670971,20.1929176 L22.9670971,20.1683744 C22.9815886,20.1324736 22.9922265,20.0943011 22.9987304,20.0548621 C22.9987304,20.0548621 22.9987304,20.0548621 22.9987304,20.0548621 C23.0004232,20.0293408 23.0004232,20.0036859 22.9987304,19.9781646 C22.9987304,19.9781646 22.9987304,19.9566893 22.9987304,19.9444177 C22.9987304,19.9321461 22.9987304,19.9229424 22.9987304,19.9137387 C22.9949502,19.8726516 22.9867644,19.8324016 22.9743971,19.7940906 L22.9743971,19.7940906 L18.9399256,8.02562631 C18.9506738,7.99615751 18.9588334,7.96529502 18.9642589,7.93358931 C18.9781664,7.81275485 18.9534152,7.68990536 18.8954544,7.59208741 C18.8374936,7.49426946 18.7510753,7.42950274 18.6552252,7.41204631 L13.4527523,6.45792942 C13.4151172,5.40049872 12.8144155,4.50934755 11.9927506,4.29199205 L11.9927506,0.460184995 C11.9927506,0.20603184 11.8293343,0 11.6277502,0 C11.426166,0 11.2627497,0.20603184 11.2627497,0.460184995 L11.2627497,4.29199205 C10.6280528,4.45682465 10.10874,5.03001236 9.89521475,5.80139883 L4.44940823,4.80126344 C4.35356714,4.78372914 4.25612781,4.81493501 4.1785425,4.88801078 C4.1009572,4.96108654 4.04958681,5.07004101 4.03574107,5.19088674 C4.03155491,5.23059483 4.03155491,5.27082675 4.03574107,5.31053484 L0.025602933,16.9992337 L0.025602933,16.9992337 C0.0132356207,17.0375447 0.00504978749,17.0777948 0.00126957058,17.1188818 C0.00126957058,17.1188818 0.00126957058,17.1403571 0.00126957058,17.1495608 C0.00126957058,17.1587645 0.00126957058,17.1710361 0.00126957058,17.1833077 C-0.000423190195,17.208829 -0.000423190195,17.2344839 0.00126957058,17.2600052 C0.00126957058,17.2600052 0.00126957058,17.2600052 0.00126957058,17.2600052 C0.00774547506,17.2994541 0.0183845876,17.3376312 0.0329029418,17.3735175 L0.0329029418,17.3980607 C0.0488060712,17.4339253 0.0684473538,17.4669431 0.0913030117,17.4962335 L0.699637073,18.2632085 C2.75983325,20.8606357 6.10004983,20.8606357 8.160246,18.2632085 L8.76858006,17.4962335 C8.79161354,17.465998 8.81126198,17.431936 8.82698013,17.3949928 L8.82698013,17.3704496 C8.84147172,17.3345488 8.85210954,17.2963764 8.85861351,17.2569373 C8.85861351,17.2569373 8.85861351,17.2569373 8.85861351,17.2569373 C8.86030627,17.231416 8.86030627,17.2057611 8.85861351,17.1802398 C8.85861351,17.1802398 8.85861351,17.1587645 8.85861351,17.1464929 C8.85861351,17.1342213 8.85861351,17.1250176 8.85861351,17.1158139 C8.85483329,17.0747269 8.84664746,17.0344768 8.83428014,16.9961658 L8.83428014,16.9961658 L5.01394224,5.83207783 L9.80274797,6.71256512 C9.85757198,7.80370794 10.5108448,8.69745358 11.3689468,8.85528909 C12.2270488,9.0131246 13.0556206,8.39194297 13.3554189,7.36602781 L18.1320579,8.2434472 L14.1584198,19.7879548 L14.1584198,19.7879548 C14.1460238,19.8262538 14.1378369,19.8665089 14.1340865,19.9076029 C14.1340865,19.9076029 14.1340865,19.9290782 14.1340865,19.9382819 C14.1340865,19.9474856 14.1340865,19.9597572 14.1340865,19.9720288 C14.1323937,19.9975501 14.1323937,20.023205 14.1340865,20.0487263 C14.1340865,20.0487263 14.1340865,20.0487263 14.1340865,20.0487263 C14.1405624,20.0881752 14.1512015,20.1263523 14.1657199,20.1622386 L14.1657199,20.1867818 C14.1816474,20.2226264 14.2012863,20.2556402 14.2241199,20.2849546 L14.832454,21.0519296 C16.8926502,23.6493568 20.2328667,23.6493568 22.2930629,21.0519296 L22.901397,20.2849546 C22.9264857,20.2581473 22.9485857,20.2271881 22.9670971,20.1929176 Z M15.0490209,19.5087759 L18.5627585,9.26505789 L22.0959627,19.5087759 L15.0490209,19.5087759 Z M0.916203999,16.7200548 L4.44940823,6.48247262 L7.96314577,16.7200548 L0.916203999,16.7200548 Z M1.24227106,17.6404248 L7.63707871,17.6404248 C5.86694476,19.8538124 3.01240501,19.8538124 1.24227106,17.6404248 L1.24227106,17.6404248 Z M11.6277502,7.95813251 C11.02159,7.94807762 10.5340258,7.32653669 10.5327488,6.56223802 C10.5327488,6.51928742 10.5327488,6.48247262 10.5327488,6.43952202 C10.5385866,6.42154559 10.5434641,6.40309702 10.5473489,6.38429982 C10.5510895,6.34660935 10.5510895,6.308478 10.5473489,6.27078753 C10.6654865,5.57212652 11.1829331,5.09866324 11.7464056,5.17365144 C12.3098781,5.24863963 12.7375156,5.84787683 12.7373515,6.56223802 C12.7373515,6.60518862 12.7373515,6.64507132 12.7373515,6.68802192 C12.7187894,6.74960828 12.7113093,6.81562397 12.7154515,6.88129962 C12.5971458,7.51670329 12.1454062,7.96392904 11.6277502,7.95813251 L11.6277502,7.95813251 Z M15.375088,20.4291459 L21.7698956,20.4291459 C19.9997617,22.6425334 17.1452219,22.6425334 15.375088,20.4291459 L15.375088,20.4291459 Z" id="Shape" fill-rule="nonzero"></path>
          </g>
          """    

  weighed_by_influence: 
    key: 'weighed_by_influence'
    name: 'Influence'
    label: 'Add weight to the opinions of people who have contributed proposals and arguments that other people have found valuable.'
    weight: (u, opinion, proposal) ->
      if !influencer_scores_initialized
        build_influencer_network()

      if !influencer_scores_initialized
        return 1 # still waiting for data to be fetched

      u = u.key or u 
      .1 + (influencer_scores[u] or 0)
    icon: (color) -> 
      color ?= 'black'
      SVG
        width: 14
        height: 14
        viewBox: "0 0 23 23"
        dangerouslySetInnerHTML: __html: """
          <g id="influence" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
              <ellipse id="Oval" fill="#{color}" fill-rule="nonzero" transform="translate(11.364066, 2.300000) scale(-1, 1) translate(-11.364066, -2.300000) " cx="11.3640662" cy="2.3" rx="2.39243499" ry="2.3"></ellipse>
              <path d="M12.5828538,4.6 L11.3640662,4.6 L10.1452786,4.6 C7.83466033,4.6 5.98108747,6.46815021 5.98108747,8.79694019 L5.98108747,13.403338 C5.98108747,13.940751 6.41274142,14.3502086 6.92056961,14.3502086 C7.4537892,14.3502086 7.86005174,13.9151599 7.86005174,13.403338 L7.86005174,8.7201669 C7.86005174,8.54102921 7.98700879,8.41307371 8.16474865,8.41307371 C8.34248851,8.41307371 8.46944556,8.54102921 8.46944556,8.7201669 L8.46944556,13.2753825 L8.46944556,22.0531293 C8.46944556,22.5905424 8.90109951,23 9.4089277,23 C9.94214729,23 10.3484098,22.5649513 10.3484098,22.0531293 L11.0085865,13.2753825 L11.6687631,13.2753825 L12.3797226,22.0531293 C12.3797226,22.5905424 12.8113765,23 13.3192047,23 C13.8524243,23 14.2586868,22.5649513 14.2586868,22.0531293 L14.2586868,13.2497914 L14.2586868,8.7201669 C14.2586868,8.54102921 14.3856439,8.41307371 14.5633837,8.41307371 C14.7411236,8.41307371 14.8680806,8.54102921 14.8680806,8.7201669 L14.8680806,13.403338 C14.8680806,13.940751 15.2997346,14.3502086 15.8075628,14.3502086 C16.3407824,14.3502086 16.7470449,13.9151599 16.7470449,13.403338 L16.7470449,8.79694019 C16.7470449,6.49374131 14.8934721,4.6 12.5828538,4.6 Z" id="Path" fill="#{color}" fill-rule="nonzero" transform="translate(11.364066, 13.800000) scale(-1, 1) translate(-11.364066, -13.800000) "></path>
              <path d="M22.3105861,0 L18.7361296,0 C18.35544,0 18.0468076,0.283811841 18.0468076,0.633885886 C18.0468076,0.983959931 18.35544,1.26777177 18.7361296,1.26777177 L20.6463788,1.26777177 L16.9489473,4.66785115 C16.6797441,4.91540471 16.6797441,5.31678126 16.9489473,5.56433482 C17.2181506,5.81188839 17.6546293,5.81188839 17.9238325,5.56433482 L21.621264,2.16425545 L21.6213559,3.92088002 C21.6213559,4.27095406 21.9299884,4.5547659 22.310678,4.5547659 C22.6913675,4.5547659 23,4.27095406 23,3.92088002 L23,0.633885886 C22.9999081,0.283727323 22.6912756,0 22.3105861,0 Z" id="Path" fill="#{color}" fill-rule="nonzero"></path>
              <path d="M5.56354114,0 L1.98908469,0 C1.60839511,0 1.29976266,0.283811841 1.29976266,0.633885886 C1.29976266,0.983959931 1.60839511,1.26777177 1.98908469,1.26777177 L3.89933392,1.26777177 L0.201902425,4.66785115 C-0.0673008082,4.91540471 -0.0673008082,5.31678126 0.201902425,5.56433482 C0.471105657,5.81188839 0.907584371,5.81188839 1.1767876,5.56433482 L4.8742191,2.16425545 L4.87431101,3.92088002 C4.87431101,4.27095406 5.18294346,4.5547659 5.56363305,4.5547659 C5.94432263,4.5547659 6.25295508,4.27095406 6.25295508,3.92088002 L6.25295508,0.633885886 C6.25286317,0.283727323 5.94423072,0 5.56354114,0 Z" id="Path" fill="#{color}" fill-rule="nonzero" transform="translate(3.126478, 2.875000) scale(-1, 1) translate(-3.126478, -2.875000) "></path>
              <path d="M22.3105861,16.1 L18.7361296,16.1 C18.35544,16.1 18.0468076,16.3838118 18.0468076,16.7338859 C18.0468076,17.0839599 18.35544,17.3677718 18.7361296,17.3677718 L20.6463788,17.3677718 L16.9489473,20.7678511 C16.6797441,21.0154047 16.6797441,21.4167813 16.9489473,21.6643348 C17.2181506,21.9118884 17.6546293,21.9118884 17.9238325,21.6643348 L21.621264,18.2642555 L21.6213559,20.02088 C21.6213559,20.3709541 21.9299884,20.6547659 22.310678,20.6547659 C22.6913675,20.6547659 23,20.3709541 23,20.02088 L23,16.7338859 C22.9999081,16.3837273 22.6912756,16.1 22.3105861,16.1 Z" id="Path" fill="#{color}" fill-rule="nonzero" transform="translate(19.873522, 18.975000) scale(1, -1) translate(-19.873522, -18.975000) "></path>
              <path d="M5.56354114,16.1 L1.98908469,16.1 C1.60839511,16.1 1.29976266,16.3838118 1.29976266,16.7338859 C1.29976266,17.0839599 1.60839511,17.3677718 1.98908469,17.3677718 L3.89933392,17.3677718 L0.201902425,20.7678511 C-0.0673008082,21.0154047 -0.0673008082,21.4167813 0.201902425,21.6643348 C0.471105657,21.9118884 0.907584371,21.9118884 1.1767876,21.6643348 L4.8742191,18.2642555 L4.87431101,20.02088 C4.87431101,20.3709541 5.18294346,20.6547659 5.56363305,20.6547659 C5.94432263,20.6547659 6.25295508,20.3709541 6.25295508,20.02088 L6.25295508,16.7338859 C6.25286317,16.3837273 5.94423072,16.1 5.56354114,16.1 Z" id="Path" fill="#{color}" fill-rule="nonzero" transform="translate(3.126478, 18.975000) scale(-1, -1) translate(-3.126478, -18.975000) "></path>
          </g>
        """

toggle_group = (view, replace_existing) ->
  _activate_opinion_view(view, 'group', replace_existing)

toggle_weight = (view, replace_existing) -> 
  _activate_opinion_view(view, 'weight', replace_existing)

toggle_opinion_filter = (view, replace_existing) -> 
  _activate_opinion_view(view, 'filter', replace_existing)

set_opinion_date_filter = (view) -> 
  _activate_opinion_view(view, 'date-filter', true)


_activate_opinion_view = (view, view_type, replace_existing) ->  
  opinion_views = fetch('opinion_views')
  opinion_views.active_views ?= {}
  active_views = opinion_views.active_views

  view_name = view.key or view.label

  if view_name of active_views && !replace_existing
    delete active_views[view_name] #activating an active view toggles it off
  else 
    if view_type == 'filter'
      if view_name == default_filters.just_you.key
        to_delete = []
        for k,v of active_views
          if v.view_type == view_type
            to_delete.push k 
        for k in to_delete
          delete active_views[k]
      else if active_views[default_filters.just_you.key]
        delete active_views[default_filters.just_you.key]

    active_views[view_name] = 
      key: view.key
      name: view.name 
      view_type: view_type
      get_salience: (u, opinion, proposal) ->
        if view.salience?
          view.salience u, opinion, proposal
        else if !view.pass? || view.pass(u, opinion, proposal)
          1
        else 
          0
      get_weight: (u, opinion, proposal) ->
        if view.weight?
          view.weight(u, opinion, proposal)
        else if (!view.pass? || view.pass?(u, opinion, proposal))
          1
        else 
          0

      get_group: if view.group? then (u, opinion, proposal) -> 
        group = view.group(u, opinion, proposal) 
        group ?= 'Unreported'
        group
      options: if view.group? then view.options


  # invalidate_proposal_sorts()
  save opinion_views








DateFilters = ->
  opinion_views = fetch 'opinion_views'
  tz_offset = new Date().getTimezoneOffset() * 60 * 1000

  cb = (activated) ->
    pass = (u, opinion, proposal) -> 
      date = new Date(opinion.updated_at).getTime()
      now = Date.now()

      earliest = latest = null
      if activated.label != 'Custom'
        clear_custom_date()

      if activated.label == 'Today'
        earliest = now - 1000 * 60 * 60 * 24

      else if activated.label == 'Past week'
        earliest = now - 1000 * 60 * 60 * 24 * 7

      else if activated.label == 'Custom'

        if date_toggle_state.start
          earliest = date_toggle_state.start + tz_offset


        if date_toggle_state.end 
          latest = date_toggle_state.end + tz_offset


      (earliest == null || earliest <= date) && (latest == null || latest >= date) 

    view = 
      key: 'date'
      salience: (u, opinion, proposal) -> if pass(u, opinion, proposal) then 1 else .1
      weight:   (u, opinion, proposal) -> if pass(u, opinion, proposal) then 1 else .1
      name: activated.label

    set_opinion_date_filter view

  clear_custom_date = ->
    date_toggle_state.start = null
    date_toggle_state.end = null
    save date_toggle_state



  date_toggle_state = fetch 'opinion-date-filter'
  date_options = [
    {
      label: 'All'
      callback: ->
        clear_custom_date()
        if opinion_views.active_views['date']
          delete opinion_views.active_views['date']
          save opinion_views
    }
    { label: 'Today', callback: cb }
    { label: 'Past week', callback: cb }
    { label: 'Custom', callback: cb }
  ]

  DIV 
    className: 'grays' # for toggle buttons

    ToggleButtons date_options, date_toggle_state

    if date_toggle_state.active == 'Custom'

      DIV 
        className: 'opinion-date-filter'

        SPAN 
          style: 
            position: 'relative'

          LABEL null,
            'From:'
          INPUT 
            type: 'date'
            id: 'start'
            name: 'opinion-start'
            defaultValue: if date_toggle_state.start then to_date_str date_toggle_state.start
            onChange: (e) ->
              date_toggle_state.start = new Date(e.target.value).getTime()
              save date_toggle_state
              cb date_options[3]            
              e.preventDefault()

        SPAN 
          style: 
            position: 'relative'
            paddingLeft: 8

          LABEL null,
            'To:'
          INPUT 
            type: 'date'
            id: 'end'
            name: 'opinion-end'
            defaultValue: if date_toggle_state.end then to_date_str date_toggle_state.end
            onChange: (e) ->
              date_toggle_state.end = new Date(e.target.value).getTime()
              save date_toggle_state
              cb date_options[3]
              e.preventDefault()

to_date_str = (ms) -> 
  ms += new Date().getTimezoneOffset() * 60 * 1000
  date = new Date(ms)
  year = date.getFullYear()
  month = ("0" + (date.getMonth() + 1)).slice(-2)
  day = ("0" + date.getDate()).slice(-2)
  "#{year}-#{month}-#{day}"






OpinionViews = ReactiveComponent
  displayName: 'OpinionViews'

  render : -> 
    @local.minimized ?= true 
    clear_all = =>
      to_remove = []
      for k,v of opinion_views.active_views
        if v.view_type in ['filter', 'weight', 'group', 'date-filter']
          to_remove.push v
      for view in to_remove
        toggle_opinion_filter view


      for attr in ['group_by', 'selected_vals_for_attribute', 'visible_attributes']
        if attr == 'group_by'
          delete opinion_views_ui[attr] if attr of opinion_views_ui
        else 
          opinion_views_ui[attr] = {}
      save opinion_views_ui

      date_state = fetch 'opinion-date-filter'
      date_state.start = date_state.end = date_state.active = null 
      save date_state

      @local.clicked_more_views = false


    return SPAN null if !fetch('/subdomain').name


    has_other_filters = get_participant_attributes().length > 0
    opinion_views = fetch 'opinion_views'
    opinion_views_ui = fetch 'opinion_views_ui'


    is_admin = fetch('/current_user').is_admin
    show_others = !customization('hide_opinions') || is_admin
    show_all_not_available = !show_others

    view_buttons = [ 
      {
        label: 'All opinions'
        callback: clear_all
        disabled: !show_others
      }
      {
        label: 'Just you'
        callback: ->
          clear_all()
          toggle_opinion_filter default_filters.just_you
      }, 
      {
        label: 'Custom view'
        disabled: !show_others
        callback: (item, previous_state) => 
          if previous_state == 'Custom view'
            if @user_has_set_a_view()
              @local.minimized = !@local.minimized
              save @local
            else 
              reset_to_default_view()
          else 
            @local.minimized = false
            clear_all()
          @local.clicked_more_views = true          
      }
    ]

    reset_to_show_all_opinions = ->
      clear_all()
      opinion_views_ui.active = 'All opinions'
      save opinion_views_ui

    reset_to_default_view = ->
      clear_all()

      dfault = customization('opinion_filters_default')
      if !show_others || dfault?.active == 'Just you'
        toggle_opinion_filter default_filters.just_you
        opinion_views_ui.active = 'Just you'
      else if dfault
        # LIMITATION: default date views not implemented

        opinion_views_ui.active = 'Custom view'

        # opinion_filters_default follows the format of opinion_views_ui
        # So we'll read the default values and activate the appropriate views.
        attributes = get_participant_attributes_with_defaults()
        if dfault.selected_vals_for_attribute?
          for key, vals of dfault.selected_vals_for_attribute
            continue if Object.keys(vals).length == 0
            attribute = attributes.find (attr) -> attr?.key == key
            opinion_views_ui.selected_vals_for_attribute[attribute.key] = vals
            opinion_views_ui.visible_attributes[attribute.key] = true
            update_view_for_attribute attribute

        if dfault.group_by
          attribute = attributes.find (attr) -> attr?.key == dfault.group_by
          set_group_by_attribute attribute       

      else       
        opinion_views_ui.active = 'All opinions'

      save opinion_views_ui


    if !opinion_views_ui.initialized      
      reset_to_default_view()
      opinion_views_ui.initialized = true 
      @local.clicked_more_views = true
      save opinion_views_ui

    if !@user_has_set_a_view() && @local.minimized && @local.clicked_more_views
      reset_to_show_all_opinions()



    DIV 
      style: (@props.style or {})
      className: 'filter_opinions_to'

      DIV 
        style: 
          marginTop: 0
          lineHeight: 1
          

        if customization('verification-by-pic') 
          VerificationProcessExplanation()

        SPAN 
          style: 
            display: 'flex'

          ToggleButtons view_buttons, opinion_views_ui, 
            minWidth: 290

          SPAN 
            style: 
              position: 'absolute'
              left: '100%'
            @MinimizeExpandButton()

      if opinion_views_ui.active == 'Custom view'
        needs_expansion = @props.additional_width && @props.style?.width
        width = 0
        if needs_expansion 
          if has_other_filters 
            width = @props.style.width + @props.additional_width 
          else 
            width = Math.min(660, @props.style.width + @props.additional_width)

        DIV
          style: 
            width: if width then width
            position: 'relative'
            right: if needs_expansion then width - @props.style.width 
            marginTop: 18

          if !@local.minimized
            DIV 
              style: 
                position: 'absolute'
                left: (document.querySelector('[data-view-state="Custom view"]')?.offsetLeft or 60) + 35 - (if needs_expansion then (@props.style.width + @props.additional_width - width ) else 0)
                top: -16

              dangerouslySetInnerHTML: __html: """<svg width="25px" height="13px" viewBox="0 0 25 13" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"><g id="Page-2" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd"><g id="Artboard" transform="translate(-1086.000000, -586.000000)" fill="#FFFFFF" stroke="#979797"><polyline id="Path" points="1087 599 1098.5 586 1110 599"></polyline></g></g></svg>"""


          if @local.minimized 
            DIV null, 

              MinimizedViews
                more_views_positioning: @props.more_views_positioning



          else 

            DIV 
              style: 
                # maxWidth: if !has_other_filters then 660
                border: '1px solid #B6B6B6'
                borderRadius: 8
                width: 'fit-content'

                margin: if @props.more_views_positioning == 'centered' then 'auto'
                float: if @props.more_views_positioning == 'right' then 'right'

              
              DIV 
                style: 
                  padding: '0px 24px'

                OpinionFilters()
                OpinionWeights()





          DIV style: clear: 'both'

  user_has_set_a_view: ->
    opinion_views = fetch 'opinion_views'
    user_has_set_a_view = false 
    for k,v of opinion_views.active_views
      user_has_set_a_view ||= v.view_type in ['filter', 'weight', 'group', 'date-filter']
    user_has_set_a_view

  MinimizeExpandButton: ->
    return SPAN(null) if !@user_has_set_a_view() || fetch('opinion_views_ui').active != 'Custom view'

    toggle_expanded = (e) =>
      @local.minimized = !@local.minimized
      save @local

    DIV null,
      BUTTON 
        className: 'like_link'
        onClick: toggle_expanded
        onKeyDown: (e) => 
          if e.which == 13 || e.which == 32 # ENTER or SPACE
            toggle_expanded(e)
            e.preventDefault()
        style: 
          fontSize: 12
          color: "#868686"
          whiteSpace: 'nowrap'
          marginLeft: 4

        if @local.minimized
          'configure view'
        else 
          'minimize'





get_participant_attributes_with_defaults = ->
  attributes = get_participant_attributes()
  attributes.unshift {key: 'date', icon: date_icon, name: 'Date', render: DateFilters}
  attributes



toggle_attribute_visibility = (attribute) ->
  opinion_views = fetch 'opinion_views'
  opinion_views_ui = fetch 'opinion_views_ui'
  opinion_views_ui.visible_attributes[attribute.key] = !opinion_views_ui.visible_attributes[attribute.key]
  if !opinion_views_ui.visible_attributes[attribute.key] && opinion_views_ui.group_by == attribute.key
    toggle_group opinion_views.active_views.group_by
    opinion_views_ui.group_by = null

  opinion_views_ui.selected_vals_for_attribute[attribute.key] = {}
  save opinion_views_ui

  if attribute.key == 'date'
    date_toggle_state = fetch 'opinion-date-filter'
    date_toggle_state.active = null 
    save date_toggle_state

  if attribute.key of opinion_views.active_views
    delete opinion_views.active_views[attribute.key]
    save opinion_views



update_view_for_attribute = (attribute) ->
  opinion_views_ui = fetch 'opinion_views_ui'
  attr_key = attribute.key
  # having no selections for an attribute paradoxically means that all values are valid.
  has_one_enabled = false 
  for val,enabled of opinion_views_ui.selected_vals_for_attribute[attr_key]
    has_one_enabled ||= enabled
  if !has_one_enabled
    opinion_views_ui.selected_vals_for_attribute[attr_key] = {}

  pass = (u) -> 
    user = fetch(u)
    val_for_user = user.tags[attr_key]
    is_array = Array.isArray(val_for_user)

    passing_vals = (val for val,enabled of opinion_views_ui.selected_vals_for_attribute[attr_key] when enabled)

    passes = false
    for passing_val in passing_vals
      if passing_val == 'true'
        passing_val = true 
      else if passing_val == 'false'
        passing_val = false

      if attribute.pass 
        passes ||= passing_val == attribute.pass(u)
      else 
        passes ||= val_for_user == passing_val || (is_array && passing_val in val_for_user)

    passes 

  view = 
    key: attr_key
    # pass: pass
    salience: (u) -> if pass(u) then 1 else .1
    weight:   (u) -> if pass(u) then 1 else .1

  toggle_opinion_filter view, has_one_enabled

set_group_by_attribute = (attribute) ->
  opinion_views_ui = fetch 'opinion_views_ui'
  opinion_views_ui.group_by = attribute.key 
  save opinion_views_ui

  view = 
    key: 'group_by'
    name: attribute.name
    group: (u, opinion, proposal) -> 
      group_val = if attribute.pass then attribute.pass(u) else fetch(u).tags[opinion_views_ui.group_by] or 'Unreported'
      if attribute.input_type == 'checklist'
        group_val.split(',')
      else 
        group_val
    options: attribute.options

  toggle_group view, true


OpinionFilters = ReactiveComponent
  displayName: 'OpinionFilters'
  render: -> 

    opinion_views = fetch 'opinion_views'
    opinion_views_ui = fetch 'opinion_views_ui'

    attributes = get_participant_attributes_with_defaults()

    active_filters = {}
    for k,v of opinion_views.active_views
      if v.view_type == 'filter'
        active_filters[k] = v 



    

    for attribute, cnt in attributes
      opinion_views_ui.selected_vals_for_attribute[attribute.key] ?= {}

    if opinion_views_ui.group_by
      all_groups = opinion_views.active_views.group_by.options
      group_colors = get_color_for_groups all_groups

    DIV null, 
      if attributes.length > 0 
        DIV 
          className: 'opinion_view_row'

          filter_icon()


          LABEL 
            className: 'opinion_view_name'
            'Narrow by'
            ':'


          UL 
            style: 
              listStyle: 'none'

            for attribute, cnt in attributes
              do (attribute) ->
                attr_name = attribute.name 
                shortened = false 
                if attr_name.length > 40
                  attr_name = "#{attr_name.substring(0,37)}..."
                  shortened = true
                LI 
                  style: 
                    display: 'inline-block'

                  BUTTON
                    title: if shortened then attribute.name
                    className: "filter opinion_view_button #{if opinion_views_ui.visible_attributes[attribute.key] then 'active' else ''}"
                    onClick: -> toggle_attribute_visibility(attribute)
                    onKeyDown: (e) => 
                      if e.which == 13 || e.which == 32 # ENTER or SPACE
                        toggle_attribute_visibility(attribute)
                        e.preventDefault()

                    if attribute.icon 
                      SPAN 
                        style: 
                          position: 'relative'
                          top: 2
                          marginRight: 7
                        attribute.icon?(opinion_views_ui.visible_attributes[attribute.key])

                    attr_name


      for attribute, cnt in attributes
        continue if !opinion_views_ui.visible_attributes[attribute.key]
        do (attribute) => 
          DIV 
            className: 'attribute_wrapper'

            DIV 
              className: 'attribute_group'


              DIV 
                className: 'attribute_name'
                "#{attribute.name}"

              if attribute.render 
                attribute.render()
              else 
                UL null, 

                  for val in attribute.options
                    is_grouped = opinion_views_ui.group_by == attribute.key
                    checked = !!opinion_views_ui.selected_vals_for_attribute[attribute.key][val]

                    val_name = val 
                    shortened = false 
                    if val_name.length > 25
                      val_name = "#{val_name.substring(0,22)}..."
                      shortened = true

                    do (val) => 
                      LI 
                        style: 
                          display: 'inline-block'
                        LABEL 
                          className: "attribute_value_selector"
                          title: if shortened then val 
                          SPAN
                            className: if is_grouped then 'toggle_switch' else ''

                            INPUT 
                              type: 'checkbox'
                              # className: 'bigger'
                              value: val
                              checked: checked
                              onChange: (e) ->
                                # create a view on the fly for this attribute
                                opinion_views_ui.selected_vals_for_attribute[attribute.key][val] = e.target.checked
                                save opinion_views_ui
                                update_view_for_attribute(attribute)

                            if is_grouped
                              SPAN 
                                className: 'toggle_switch_circle'
                                style: 
                                  backgroundColor: if checked then group_colors[val]

                          SPAN 
                            className: 'attribute_value_value'
                            val_name

            BUTTON
              className: 'attribute_close'
              onClick: -> toggle_attribute_visibility(attribute)
              onKeyDown: (e) => 
                if e.which == 13 || e.which == 32 # ENTER or SPACE
                  toggle_attribute_visibility(attribute)
                  e.preventDefault()

              'x'

      if attributes.length > 1 
        cur_val = -1
        for attr, idx in attributes
          if opinion_views_ui.group_by == attr.key 
            cur_val = idx
        DIV 
          className: 'opinion_view_row'
          style: 
            borderTop: '1px dotted #DEDDDD' 

          group_by_icon()

          LABEL 
            className: 'opinion_view_name'
            'Color code by'
            ':'

          SELECT 
            style: 
              maxWidth: '100%'
              marginRight: 12
              borderColor: '#bbb'
              backgroundColor: '#f9f9f9'
              borderRadius: 2

            onChange: (ev) -> 
              if ev.target.value != null
                attribute = attributes[ev.target.value]
                opinion_views_ui.group_by = attribute?.key
              else 
                opinion_views_ui.group_by = null

              if opinion_views_ui.group_by && (!opinion_views_ui.visible_attributes[opinion_views_ui.group_by] ||  \
                                  (o for o,val of opinion_views_ui.selected_vals_for_attribute[opinion_views_ui.group_by] when val).length == 0)
                            # if no attribute value is selected, which mean all are enabled, select them all
                opinion_views_ui.visible_attributes[opinion_views_ui.group_by] = true 
                for option in attribute.options 
                  opinion_views_ui.selected_vals_for_attribute[attribute.key][option] = true
              save opinion_views_ui

              if opinion_views_ui.group_by
                set_group_by_attribute attribute 

              else 
                delete opinion_views.active_views.group_by
                save opinion_views


            value: cur_val

            OPTION 
              value: null
              ""
            for attribute,idx in attributes 
              continue if !attribute.options
              do (attribute) =>
                OPTION 
                  value: idx 
                  attribute.name or attribute.question



get_activated_weights = ->
  opinion_views = fetch 'opinion_views'

  activated_weights = {}
  for k,v of opinion_views.active_views
    if v.view_type == 'weight'
      activated_weights[k] = v 
  activated_weights


OpinionWeights = ReactiveComponent
  displayName: 'OpinionWeights'
  render: ->
    opinion_views = fetch 'opinion_views'

    activated_weights = get_activated_weights()
    DIV 
      className: 'opinion_view_row'
      style: 
        borderTop: '1px dotted #DEDDDD' 

      weigh_icon()

      LABEL 
        className: 'opinion_view_name'

        'Weigh by'
        ':'

      UL 
        style: 
          listStyle: 'none'

        for k,v of default_weights
          do (k,v) ->
            LI 
              style: 
                marginRight: 8
                display: 'inline-block'

              BUTTON 
                'data-tooltip': v.label
                className: "weight opinion_view_button #{if activated_weights[k] then 'active' else ''}"
                onClick: ->
                  toggle_weight v
                onKeyDown: (e) -> 
                  if e.which == 13 || e.which == 32 # ENTER or SPACE
                    toggle_weight v
                    e.preventDefault()

                if v.icon
                  v.icon if activated_weights[k] then 'white'

                SPAN 
                  style: 
                    paddingLeft: if v.icon then 10

                  v.name



MinimizedViews = ReactiveComponent
  displayName: 'MinimizedViews'
  render: -> 

    minimized_views = []
    opinion_views = fetch 'opinion_views'
    opinion_views_ui = fetch 'opinion_views_ui'

    attributes = get_participant_attributes_with_defaults()

    for attribute, cnt in attributes
      continue if !opinion_views_ui.visible_attributes[attribute.key]

      is_grouped = opinion_views_ui.group_by == attribute.key 

      console.log attribute.key, is_grouped, opinion_views_ui
      checked = []
      unchecked = []
      if attribute.key == 'date'
        
        filter_str = opinion_views.active_views['date']?.name 
        continue if !filter_str

        if filter_str == 'Custom'
          date_toggle_state = fetch 'opinion-date-filter'


          if !date_toggle_state.start && !date_toggle_state.end 
            filter_str = 'any date'
          else if !date_toggle_state.start
            filter_str = "up to #{to_date_str(date_toggle_state.end)}"
          else if !date_toggle_state.end
            filter_str = "after #{to_date_str(date_toggle_state.start)}"
          else 
            filter_str = "#{to_date_str(date_toggle_state.start)} - #{to_date_str(date_toggle_state.end)}" 

      else 
        for val in attribute.options
          if !!opinion_views_ui.selected_vals_for_attribute[attribute.key][val]
            checked.push val 
          else 
            unchecked.push val

        continue if !is_grouped && (checked.length == 0 || checked.length == attribute.options.length)

        checked_string = "" 
        unchecked_string = ""
        for val,idx in checked 
          if val.length > 25
            val = "#{val.substring(0,22)}..."
          if idx == checked.length - 1 && checked.length > 1
            checked_string += ' and '
          checked_string += "&ldquo;#{val}&rdquo;" 
          if idx != checked.length - 1 && checked.length > 2
            checked_string += ', '

        for val,idx in unchecked 
          if val.length > 25
            val = "#{val.substring(0,22)}..."
          if idx == unchecked.length - 1 && unchecked.length > 1
            unchecked_string += ' and '
          unchecked_string += "&ldquo;#{val}&rdquo;" 
          if idx != unchecked.length - 1 && unchecked.length > 2
            unchecked_string += ', '

        if unchecked_string.length < checked_string.length
          filter_str = unchecked_string
          if unchecked_string.length > 0
            filter_str = "Filter out #{filter_str}"
        else 
          filter_str = checked_string
          if checked_string.length > 0
            filter_str = "Narrow to #{filter_str}"


      minimized_views.push
        name: attribute.name 
        label: '' #if is_grouped then 'Color code by' else 'Narrow by'
        icon: if is_grouped then group_by_icon # else filter_icon
        filters: filter_str
        toggle: do (attribute, is_grouped) -> ->
          if is_grouped
            delete opinion_views_ui.group_by
            save opinion_views_ui
            toggle_group opinion_views.active_views.group_by, false 
          # else                           
          toggle_attribute_visibility(attribute)


    activated_weights = get_activated_weights()
    for k,v of default_weights
      continue if !activated_weights[k]
      minimized_views.push
        name: v.name 
        label: 'Weigh by'
        # icon: weigh_icon
        toggle: do (v) -> ->
          toggle_weight v

    UL 
      style: 
        listStyle: 'none'
        textAlign: if @props.more_views_positioning == 'centered' then 'center' else 'right'
      for view in minimized_views
        do (view) ->
          LI  
            className: 'minimized_view_wrapper'

            SPAN 
              className: "minimized_view"

              view.icon?(16)

              view.label

              SPAN
                className: "minimized_view_name" 
                style: 
                  paddingLeft: 4

                view.name
                if view.filters
                  ": "

              if view.filters 
                SPAN 
                  style: 
                    paddingLeft: 4
                  dangerouslySetInnerHTML: __html: view.filters

              BUTTON 
                className: "minimized_view_close" 
                onClick: ->
                  view.toggle()
                onKeyDown: (e) -> 
                  if e.which == 13 || e.which == 32 # ENTER or SPACE
                    view.toggle()
                    e.preventDefault()
                'x'



filter_icon = (height) -> 
  height ?= 27
  SVG 
    className: 'opinion_view_class' 
    width: 33 / 27 * height
    height: height
    viewBox: "0 0 33 27" 
    dangerouslySetInnerHTML: __html: """
      <g id="final-push,-filters,-weights,-group-by" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
          <g id="Artboard-Copy-47" transform="translate(-373.000000, -868.000000)">
              <g id="Group-22" transform="translate(333.000000, 843.000000)">
                  <g id="filter2" transform="translate(40.000000, 25.000000)">
                      <circle id="Oval" fill-opacity="0.491815314" fill="#B0B0B0" cx="4.5" cy="4.5" r="4.5"></circle>
                      <circle id="Oval" fill-opacity="0.491815314" fill="#B0B0B0" cx="15.5" cy="4.5" r="4.5"></circle>
                      <circle id="Oval" fill="#5F5E5E" cx="15.5" cy="22.5" r="4.5"></circle>
                      <circle id="Oval" fill-opacity="0.491815314" fill="#B0B0B0" cx="25.5" cy="4.5" r="4.5"></circle>
                      <line x1="2.1744186" y1="13" x2="31.8255814" y2="13" id="Line" stroke="#757575" stroke-linecap="square" stroke-dasharray="0,2"></line>
                  </g>
              </g>
          </g>
      </g>
    """    
    
group_by_icon = (height) ->
  height ?= 19
  SVG
    className: 'opinion_view_class' 
    width: 34/19 * height  
    height: height
    viewBox: "0 0 34 19" 

    dangerouslySetInnerHTML: __html: """
      <g id="final-push,-filters,-weights,-group-by" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
          <g id="Artboard-Copy-47" transform="translate(-371.000000, -937.000000)">
              <g id="Group-22" transform="translate(333.000000, 843.000000)">
                  <g id="weigh" transform="translate(39.000000, 94.000000)">
                      <circle id="Oval" fill="#F09552" cx="6.45454545" cy="13.1818182" r="5"></circle>
                      <circle id="Oval" fill="#F09552" cx="16.2727273" cy="13" r="5"></circle>
                      <circle id="Oval" fill="#5E91E9" cx="10.8181818" cy="5" r="5"></circle>
                      <circle id="Oval" fill="#BC62C4" cx="27.8181818" cy="13" r="5"></circle>
                      <line x1="0.228571429" y1="18.4545455" x2="31.7714286" y2="18.4545455" id="Line" stroke="#A7A7A7" stroke-linecap="square"></line>
                  </g>
              </g>
          </g>
      </g>
    """


weigh_icon = (height) ->
  height ?= 18
  SVG
    className: 'opinion_view_class' 
    width: height * 34/18 
    height: height
    viewBox: "0 0 34 18" 

    dangerouslySetInnerHTML: __html: """
      <g id="final-push,-filters,-weights,-group-by" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
          <g id="Artboard-Copy-47" transform="translate(-372.000000, -759.000000)">
              <g id="Group-22" transform="translate(333.000000, 602.000000)">
                  <g id="weigh" transform="translate(40.000000, 157.000000)">
                      <circle id="Oval" fill="#9C9C9C" cx="4.36363636" cy="13.0909091" r="2.90909091"></circle>
                      <circle id="Oval" fill="#9C9C9C" cx="27.6363636" cy="13.0909091" r="4.36363636"></circle>
                      <circle id="Oval" fill="#9C9C9C" cx="13.8181818" cy="8" r="8"></circle>
                      <line x1="0.228571429" y1="17.4545455" x2="31.7714286" y2="17.4545455" id="Line" stroke="#A7A7A7" stroke-linecap="square"></line>
                  </g>
              </g>
          </g>
      </g>
    """

date_icon = (activated) ->
  SVG 
    width: 13
    height: 12 
    viewBox: "0 0 96 86"
    dangerouslySetInnerHTML: __html: """

    <g stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
        <g transform="translate(-234.000000, -823.000000)" fill="#{if activated then '#ffffff' else '#000000'}" fill-rule="nonzero">
            <g transform="translate(234.500000, 823.000000)">
                <path d="M84.3,5.7 L73.1,5.7 L73.1,2.9 C73.1,1.3 71.8,-1.77635684e-15 70.2,-1.77635684e-15 C68.6,-1.77635684e-15 67.3,1.3 67.3,2.9 L67.3,5.7 L50.4,5.7 L50.4,2.9 C50.4,1.3 49.1,-1.77635684e-15 47.5,-1.77635684e-15 C45.9,-1.77635684e-15 44.6,1.3 44.6,2.9 L44.6,5.7 L27.7,5.7 L27.7,2.9 C27.7,1.3 26.4,-1.77635684e-15 24.8,-1.77635684e-15 C23.2,-1.77635684e-15 21.9,1.3 21.9,2.9 L21.9,5.7 L10.7,5.7 C4.8,5.7 0,10.5 0,16.4 L0,75.2 C0,81.1 4.8,85.9 10.7,85.9 L84.4,85.9 C90.3,85.9 95.1,81.1 95.1,75.2 L95.1,16.4 C95,10.5 90.2,5.7 84.3,5.7 Z M89.2,75.1 C89.2,77.8 87,79.9 84.4,79.9 L10.7,79.9 C8,79.9 5.9,77.7 5.9,75.1 L5.9,16.4 C5.9,13.7 8.1,11.6 10.7,11.6 L21.9,11.6 L21.9,14.4 C21.9,16 23.2,17.3 24.8,17.3 C26.4,17.3 27.7,16 27.7,14.4 L27.7,11.6 L44.6,11.6 L44.6,14.4 C44.6,16 45.9,17.3 47.5,17.3 C49.1,17.3 50.4,16 50.4,14.4 L50.4,11.6 L67.3,11.6 L67.3,14.4 C67.3,16 68.6,17.3 70.2,17.3 C71.8,17.3 73.1,16 73.1,14.4 L73.1,11.6 L84.3,11.6 C87,11.6 89.1,13.8 89.1,16.4 L89.1,75.1 L89.2,75.1 Z" id="Shape"></path>
                <path d="M29.9,27.9 L21.4,27.9 C19.8,27.9 18.6,29.2 18.6,30.7 C18.6,32.3 19.9,33.5 21.4,33.5 L29.9,33.5 C31.5,33.5 32.7,32.2 32.7,30.7 C32.8,29.2 31.5,27.9 29.9,27.9 Z" id="Path"></path>
                <path d="M73.6,27.9 L65.1,27.9 C63.5,27.9 62.3,29.2 62.3,30.7 C62.3,32.3 63.6,33.5 65.1,33.5 L73.6,33.5 C75.2,33.5 76.4,32.2 76.4,30.7 C76.4,29.2 75.1,27.9 73.6,27.9 Z" id="Path"></path>
                <path d="M51.7,27.9 L43.2,27.9 C41.6,27.9 40.4,29.2 40.4,30.7 C40.4,32.3 41.7,33.5 43.2,33.5 L51.7,33.5 C53.3,33.5 54.5,32.2 54.5,30.7 C54.6,29.2 53.3,27.9 51.7,27.9 Z" id="Path"></path>
                <path d="M29.9,45.2 L21.4,45.2 C19.8,45.2 18.6,46.5 18.6,48 C18.6,49.6 19.9,50.8 21.4,50.8 L29.9,50.8 C31.5,50.8 32.7,49.5 32.7,48 C32.8,46.5 31.5,45.2 29.9,45.2 Z" id="Path"></path>
                <path d="M73.6,45.2 L65.1,45.2 C63.5,45.2 62.3,46.5 62.3,48 C62.3,49.6 63.6,50.8 65.1,50.8 L73.6,50.8 C75.2,50.8 76.4,49.5 76.4,48 C76.4,46.5 75.1,45.2 73.6,45.2 Z" id="Path"></path>
                <path d="M51.7,45.2 L43.2,45.2 C41.6,45.2 40.4,46.5 40.4,48 C40.4,49.6 41.7,50.8 43.2,50.8 L51.7,50.8 C53.3,50.8 54.5,49.5 54.5,48 C54.6,46.5 53.3,45.2 51.7,45.2 Z" id="Path"></path>
                <path d="M29.9,62.5 L21.4,62.5 C19.8,62.5 18.6,63.8 18.6,65.3 C18.6,66.9 19.9,68.1 21.4,68.1 L29.9,68.1 C31.5,68.1 32.7,66.8 32.7,65.3 C32.8,63.8 31.5,62.5 29.9,62.5 Z" id="Path"></path>
                <path d="M73.6,62.5 L65.1,62.5 C63.5,62.5 62.3,63.8 62.3,65.3 C62.3,66.9 63.6,68.1 65.1,68.1 L73.6,68.1 C75.2,68.1 76.4,66.8 76.4,65.3 C76.4,63.8 75.1,62.5 73.6,62.5 Z" id="Path"></path>
                <path d="M51.7,62.5 L43.2,62.5 C41.6,62.5 40.4,63.8 40.4,65.3 C40.4,66.9 41.7,68.1 43.2,68.1 L51.7,68.1 C53.3,68.1 54.5,66.8 54.5,65.3 C54.6,63.8 53.3,62.5 51.7,62.5 Z" id="Path"></path>
            </g>
        </g>
    </g>
    """

VerificationProcessExplanation = ReactiveComponent
  displayName: 'VerificationProcessExplanation'
  render: -> 
    users = fetch '/users'
    callout = "about verification"
    DIV 
      style: 
        position: 'absolute'
        right: -sizeWhenRendered(callout, {fontSize: 12}).width
        top: -14

      SPAN 
        style: 
          color: "#aaa"
          fontSize: 14

        SPAN 
          style: 
            textDecoration: 'underline'
            cursor: 'pointer'
            color: if @local.describe_process then logo_red
          onClick: => 
            @local.describe_process = !@local.describe_process
            save @local
          callout

      if @local.describe_process
        para = 
          marginBottom: 20

        DIV 
          style: 
            textAlign: 'left'
            position: 'absolute'
            right: 0
            top: 40
            width: 650
            zIndex: 999
            padding: "20px 40px"
            backgroundColor: '#eee'
            #boxShadow: '0 1px 2px rgba(0,0,0,.3)'
            fontSize: 18

          SPAN 
            style: cssTriangle 'top', '#eee', 16, 8,
              position: 'absolute'
              right: 50
              top: -8


          DIV style: para,

            """Filters help us understand the opinions of the stakeholder groups. \
               Filters are conjunctive: only users that pass all active filters are shown.
               These are the filters:"""

          DIV style: para,
            SPAN 
              style:
                fontWeight: 700
              'Users'
            """. Verified users have emailed us a verification image to validate their account.  
               We have also verified a few other people via other media channels, like Reddit. """
            SPAN style: fontStyle: 'italic', 
              "Verification results shown below."

          DIV style: para,
            SPAN 
              style:
                fontWeight: 700
              'Miners'

            ". Miners are "
            OL 
              style: 
                marginLeft: 20 
              LI null,
                'Users who control a mining pool with > 1% amount of hashrate'
              LI null,
                'Users who control > 1% amount of hashrate'
            'We verify hashrate by consulting '
            A 
              href: 'https://blockchain.info/pools'
              target: '_blank'
              style: 
                textDecoration: 'underline'

              'https://blockchain.info/pools'
            '.'

          DIV style: para,
            SPAN 
              style:
                fontWeight: 700
              'Developers'

            """. Bitcoin developers self-report by editing their user profile. If we recognize 
               someone as a committer or maintainer of Core or XT, we assign it. 
               We aren’t satisfied by our criteria for developer. We hope to work with 
               the community to define a more robust standard for 'reputable technical voice'.""" 

          DIV style: para,
            SPAN 
              style:
                fontWeight: 700
              'Businesses'

            """. Bitcoin businesses self-report by editing their user profile. Business accounts
               are either users who operate the business or an account that will represent that 
               businesses' official position.""" 

          DIV style: para,
            "These filters aren’t perfect. If you think there is a problem, email us at "
            A
              href: "mailto:admin@consider.it"
              style: 
                textDecoration: 'underline'
              'admin@consider.it'

            ". We will try to make a more trustless process in the future."

          DIV 
            style: {}

            DIV 
              style: 
                fontWeight: 600
                fontSize: 26

              'Verification status'

            for user in users.users 
              user = fetch user 
              if user.tags.verified && user.tags.verified.toLowerCase() not in ['no', 'false']
                DIV 
                  style:
                    marginTop: 20

                  DIV 
                    style: 
                      fontWeight: 600

                    user.name


                  if user.tags.verified?.indexOf('http') == 0
                    IMG 
                      src: user.tags.verified
                      style: 
                        width: 400
                  else 
                    DIV 
                      style: 
                        fontStyle: 'italic'

                      user.tags.verified




styles += """

  button.opinion_view_button {
    border: 1px solid #E0E0E0;
    border-bottom-color: #aaa;
    background-color: #F0F0F0;
    // box-shadow: inset 0 -1px 1px 0 rgba(0,0,0,0.62);
    border-radius: 8px;    
    font-size: 12px;
    color: #000000;
    font-weight: 400;
  }
  button.opinion_view_button.filter {
    padding: 4px 12px;
    margin: 0 8px 8px 0;

  }
  button.opinion_view_button.weight {
    width: 100%;
    display: flex;
    padding: 4px 12px 4px 12px;
    text-align: left;
    align-items: center;
    margin-right: 12px;

  }

  button.opinion_view_button.active {
    background-color: #{focus_blue};
    color: white;
    border-color: #{focus_blue};
  }


  .opinion_view_row {
    padding: 16px 0px;
    display: flex;
  } 
  svg.opinion_view_class {
    display: block; 
    margin-right: 18px;
  }

  .opinion_view_name {
    margin-right: 18px;    
    font-weight: 600;
    font-size: 16px;
    white-space: nowrap;
  }

  .attribute_wrapper {
    display: flex;    
    margin-bottom: 8px;
  }

  .attribute_group, .minimized_view {
    border-radius: 8px;    
    padding: 8px 16px;
  }

  .attribute_group {
    margin-left: 50px;
    width: 100%;
    background-color: #F3F3F3;  
    display: flex;  
    align-items: center;      
  }

  .attribute_name {
    font-weight: 600;
    font-size: 12px;
    text-align: right;   
    width: 100px;
    padding-right: 16px; 
  }
  .attribute_close, .minimized_view_close {
    font-size: 12px;
    color: #000000;
    background-color: transparent;
    border: none;
  }
  .minimized_view_close {
    position: absolute;
    right: -17px;
  }

  .minimized_view_wrapper {
    margin-bottom: 4px;
    margin-left: 24px;    
    display: inline-block;
    font-size: 12px; 
    position: relative;   
  }

  .minimized_view {
    color: #1a5fa5;
    background-color: #e4edf7;
    width: fit-content;
    position: relative;
    display: inline-block;
  }
  .minimized_view_name {
    font-weight: 700;
  }

  .minimized_view svg.opinion_view_class {
    display: inline;
    position: relative;
    top: 3px;
    height: 12px;
  }

  .attribute_value_selector {
    display: flex; 
    align-items: center;
    cursor: pointer;
    margin-right: 18px;
  }
  .attribute_value_selector input {

  }
  .attribute_value_selector .attribute_value_value {
    padding-left: 8px;
    font-size: 12px;
    font-weight: 400;
    font-family: 'Fira Sans Condensed';
  }

  .opinion-date-filter {
    display: inline-block;
    margin-top: 8px;
  }
  .opinion-date-filter label {
    padding: 0 8px 0 18px;
    color: #666;
    font-size: 12px;
  }
  
  .opinion-date-filter input {
    font-size: 12px;
    width: 128px;
  }

"""



styles += """
  .toggle_buttons {
    list-style: none;
    margin: auto;
    text-align: center
  }
  .toggle_buttons li {
    display: inline-block;
  }
  button.sort_proposals {
    border-radius: 8px;
  }
  button.sort_proposals, .toggle_buttons button {
    background-color: white;
    color: #{focus_blue};
    font-weight: 600;
    font-size: 12px;
    border: 1px solid;
    border-color: #{focus_blue};
    border-right: none;
    padding: 4px 16px;
  }  
  .toggle_buttons li:first-child button {
    border-radius: 8px 0 0 8px;
    border-right: none;
  }
  .toggle_buttons li:last-child button {
    border-radius: 0px 8px 8px 0px;
    border-right: 1px solid;
  }

  button.sort_proposals, .toggle_buttons .active button {
    background-color: #{focus_blue};
    color: white;
  }

  .toggle_buttons button[disabled] {
    opacity: .45;
    cursor: default;
  }

  .grays .toggle_buttons button {
    color: #444;
    border-color: #444;
  }
  .grays .toggle_buttons .active button {
    background-color: #444;
    color: white;
  }
"""

window.ToggleButtons = (items, view_state, style) ->
  toggle_state = fetch view_state 
  toggle_state.active ?= items[0]?.label

  toggled = (e, item) ->
    prev = view_state.active
    view_state.active = item.label
    save view_state

    item.callback?(item, prev)

  UL 
    key: 'toggle buttons'
    className: 'toggle_buttons'
    style: style or {}

    for item in items
      do (item) =>
        LI 
          className: if view_state.active == item.label then 'active'
          'data-view-state': item.label
          
          BUTTON
            disabled: item.disabled 
            onClick: (e) -> toggled(e, item) 
            onKeyDown: (e) -> 
              if e.which == 13 || e.which == 32 # ENTER or SPACE
                toggled(e, item)
                e.preventDefault()

            item.label

window.OpinionViews = OpinionViews
