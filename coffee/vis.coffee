
class BubbleChart
  constructor: (data) ->
    @data = data
    @width = 940
    @height = 600

    @tooltip = CustomTooltip("gates_tooltip", 240)

    # locations the nodes will move towards
    # depending on which view is currently being
    # used
    @center = {x: @width / 2, y: @height / 2}
    @block_centers = {
      "Block 1": {x: @width / 4, y: @height / 2},
      "Block 2": {x: @width / 2, y: @height / 2},
      "Block 3": {x: 3 * @width / 4, y: @height / 2}
    }

    # used when setting up force and
    # moving around nodes
    @layout_gravity = -0.01
    @damper = 0.1

    # these will be set in create_nodes and create_vis
    @vis = null
    @nodes = []
    @force = null
    @circles = null

    # nice looking colors - no reason to buck the trend
    @fill_color = d3.scale.ordinal()
      .domain(["POLITISAMARBEJDE", "ERHVERV", "ALMEN", "FAMILIE", "ASYL OG UDLÆNDINGE", "RHVERV"])
      .range(["#d84b2a", "#beccae", "#7aa25c", "#ffa500", "#800000", "#333333"])

    # use the max weight in the data as the max in the scale's domain
    max_amount = d3.max(@data, (d) -> d.weight)
    @radius_scale = d3.scale
      .pow()
      .exponent(0.5)
      .domain([0, max_amount])
      .range([2, 15])
    
    this.create_nodes()
    this.create_vis()

  # create node objects from original data
  # that will serve as the data behind each
  # bubble in the vis, then add each node
  # to @nodes to be used later
  create_nodes: () =>
    @data.forEach (d) =>
      d.weight = parseInt(d.weight) * 5
      d.radius = @radius_scale(d.weight)
      d.x = Math.random() * 900
      d.y = Math.random() * 800
      d.group = d.area
      d.block = "Block #{d.block}"
      @nodes.push d
    @nodes.sort (a,b) -> b.weight - a.weight

  # create svg at #vis and then 
  # create circle representation for each node
  create_vis: () =>
    @vis = d3.select("#vis").append("svg")
      .attr("width", @width)
      .attr("height", @height)
      .attr("id", "svg_vis")

    @circles = @vis.selectAll("circle")
      .data(@nodes, (d) -> d.id)

    # used because we need 'this' in the 
    # mouse callbacks
    that = this

    # radius will be set to 0 initially.
    # see transition below
    @circles.enter().append("circle")
      .attr("r", 0)
      .attr("fill", (d) => @fill_color(d.group))
      .attr("stroke-width", 2)
      .attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
      .attr("id", (d) -> "bubble_#{d.id}")
      .on("mouseover", (d,i) -> that.show_details(d,i,this))
      .on("mouseout", (d,i) -> that.hide_details(d,i,this))

    # Fancy transition to make bubbles appear, ending with the
    # correct radius
    @circles.transition().duration(2000).attr("r", (d) -> d.radius)


  # Charge function that is called for each node.
  # Charge is proportional to the diameter of the
  # circle (which is stored in the radius attribute
  # of the circle's associated data.
  # This is done to allow for accurate collision 
  # detection with nodes of different sizes.
  # Charge is negative because we want nodes to 
  # repel.
  # Dividing by 8 scales down the charge to be
  # appropriate for the visualization dimensions.
  charge: (d) ->
    -Math.pow(d.radius, 2.0) / 8

  # Starts up the force layout with
  # the default values
  start: () =>
    @force = d3.layout.force()
      .nodes(@nodes)
      .size([@width, @height])

  # Sets up force layout to display
  # all nodes in one circle.
  display_group_all: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_center(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.hide_blocks()

  # Moves all circles towards the @center
  # of the visualization
  move_towards_center: (alpha) =>
    (d) =>
      d.x = d.x + (@center.x - d.x) * (@damper + 0.02) * alpha
      d.y = d.y + (@center.y - d.y) * (@damper + 0.02) * alpha

  # sets the display of bubbles to be separated
  # into each block. Does this by calling move_towards_block
  display_by_block: () =>
    @force.gravity(@layout_gravity)
      .charge(this.charge)
      .friction(0.9)
      .on "tick", (e) =>
        @circles.each(this.move_towards_block(e.alpha))
          .attr("cx", (d) -> d.x)
          .attr("cy", (d) -> d.y)
    @force.start()

    this.display_blocks()

  # move all circles to their associated @block_centers 
  move_towards_block: (alpha) =>
    (d) =>
      target = @block_centers[d.block]
      d.x = d.x + (target.x - d.x) * (@damper + 0.02) * alpha * 1.1
      d.y = d.y + (target.y - d.y) * (@damper + 0.02) * alpha * 1.1

  # Method to display block titles
  display_blocks: () =>
    blocks_x = {"Block 1": 160, "Block 2": @width / 2, "Block 3": @width - 160}
    blocks_data = d3.keys(blocks_x)
    blocks = @vis.selectAll(".blocks")
      .data(blocks_data)

    blocks.enter().append("text")
      .attr("class", "blocks")
      .attr("x", (d) => blocks_x[d] )
      .attr("y", 40)
      .attr("text-anchor", "middle")
      .text((d) -> d)

  # Method to hide block titiles
  hide_blocks: () =>
    blocks = @vis.selectAll(".blocks").remove()

  show_details: (data, i, element) =>
    d3.select(element).attr("stroke", "black")
    content = "<span class=\"name\">Title:</span><span class=\"value\"> #{data.title}</span><br/>"
    content +="<span class=\"name\">Area:</span><span class=\"value\"> #{data.area}</span><br/>"
    content +="<span class=\"name\">Description:</span><span class=\"value\"> #{data.description}</span><br/>"
    content +="<span class=\"name\">Block:</span><span class=\"value\"> #{data.block}</span>"
    @tooltip.showTooltip(content,d3.event)

  hide_details: (data, i, element) =>
    d3.select(element).attr("stroke", (d) => d3.rgb(@fill_color(d.group)).darker())
    @tooltip.hideTooltip()


root = exports ? this

$ ->
  chart = null

  render_vis = (csv) ->
    chart = new BubbleChart csv
    chart.start()
    root.display_all()

  root.display_all = () =>
    console.log 'a;lksdfj'
    chart.display_group_all()

  root.display_block = () =>
    chart.display_by_block()

  root.toggle_view = (view_type) =>
    if view_type == 'block'
      root.display_block()
    else
      root.display_all()

  d3.csv "data/laws.csv", render_vis

$('#view_selection a').click ->
  $('#view_selection a').removeClass 'active'
  $(this).toggleClass 'active'
  toggle_view $(@).attr 'id'
