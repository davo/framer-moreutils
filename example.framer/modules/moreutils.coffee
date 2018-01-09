# Helpers

_.assign Utils,

	# pin a layer to another layer, so that if that layer moves, the pinned layer moves with it
	# @example    Utils.pin(layerA, layerB, ['left', 'right'], 8)
	pin: (layer, targetLayer, directions, distance) ->
		if not _.isArray(directions) then directions = [directions]
		
		for direction in directions
			do (layer, targetLayer, direction, distance) ->
				switch direction
					when "left"
						props = ['x']
						lProp = 'maxX'
						distance ?= targetLayer.x -
							(layer.x + layer.width)
						getDifference = -> targetLayer.screenFrame.x - distance
					when "right"
						props = ['x', 'width']
						lProp = 'x'
						distance ?= layer.x -
							(targetLayer.x + targetLayer.width)
						getDifference = -> distance +
							(targetLayer.x + targetLayer.width) 
					when "top"
						props = ['y']
						lProp = 'maxY'
						distance ?= targetLayer.y -
							(layer.y + layer.height)
						getDifference = -> targetLayer.y - distance
					when "bottom"
						props = ['y', 'height']
						lProp = 'y'
						distance ?= layer.y -
							(targetLayer.y + targetLayer.height)
						getDifference = -> distance + 
							(targetLayer.y + targetLayer.height) 
					else
						throw 'Utils.pin - directions can only be top, right, bottom or left.'
				
				
				for prop in props
					setPin =
						targetLayer: targetLayer
						direction: direction
						event: "change:#{prop}"
						func: -> layer[lProp] = getDifference()
				
					layer.pins ?= []
					layer.pins.push(setPin)
					
					targetLayer.on setPin.event, setPin.func
	
	
	# Remove all of a layer's pins, or pins from a certain target layer and/or direction
	# @example    Utils.unpin(layer)
	unpin: (layer, targetLayer, direction) ->
		
		setPins = _.filter layer.pins, (p) ->
			isLayer = if targetLayer? then p.targetLayer is targetLayer else true
			isDirection = if direction? then p.direction is direction else true
			
			return isLayer and isDirection
		
		for setPin in setPins
			setPin.targetLayer.off(setPin.event, setPin.func)
	

	# Set a layer's contraints to its parent
	# @example    Utils.constrain(layer, {left: true, top: true, asepectRatio: true})
	constrain: (layer, opts) ->
		if not layer.parent? then throw 'Utils.constrain requires a layer with a parent.'
		
		if not _.isArray(opts) then opts = [opts]

		options =
			left: false, 
			top: false, 
			right: false, 
			bottom: false,
			height: false
			width: false
			aspectRatio: false

		for opt in opts
			options[opt] = true
		
		values = 
			left: if options.left then layer.x else null
			height: layer.height
			centerAnchorX: layer.midX / layer.parent?.width
			width: layer.width
			right: if options.right then layer.parent?.width - layer.maxX else null
			top: if options.top then layer.y else null
			centerAnchorY: layer.midY / layer.parent?.height
			bottom: if options.bottom then layer.parent?.height - layer.maxY else null
			widthFactor: null
			heightFactor: null
			aspectRatioLocked: options.aspectRatio
		
		unless options.top and options.bottom
			if options.height
				values.heightFactor = layer.height / layer.parent?.height
				
		unless options.left and options.right 
			if options.width
				values.widthFactor = layer.width / layer.parent?.width
		
		layer.constraintValues = values

	# execute a function that is bound to the target (keeps code a bit more dry)
	# @example    Utils.build(layer, -> @name = 'My Layer')
	build: (target, func) ->
		do _.bind(func, target)
	
	
	# define a property on the layer with a getter/setter that emits a change event,
	# and optionally an initial value and callback
	# @example    Utils.define(layer, 'toggleStatus', false, layer.setToggleStatus)
	define: (layer, property, value, callback) ->
		Object.defineProperty layer,
			property,
			get: -> return layer["_#{property}"]
			set: (value) -> 
				return if value is layer["_#{property}"]
	
				layer["_#{property}"] = value
				layer.emit("change:#{property}", value, layer)
				
		if callback? and typeof callback is 'function'
			layer.on("change:#{property}", callback)
		
		layer[property] = value
	
	
	# set all layers in an array to the same property value
	# @example    Utils.align(childLayers, 'midY', parent.midY)
	align: (array = [], property, target, animate = false) ->
		
		animate ?= typeof target is 'boolean' and target is true
		target ?= _.minBy(array, property)?[property]
				
		for layer, i in array	
			if typeof target is 'function' then tar = target(i)
		
			if animate
				layer.animate {"#{property}": tar ? target}
				continue
			
			layer[property] = tar ? target
	
	
	# distribute layers in an array between two values
	# @example    Utils.distribute(childLayers, 'midX', parent.x + 32, parent.width - 32)
	distribute: (array = [], property, start, end, animate = false) ->
		
		animate ?= typeof start is 'boolean' and start is true
		step = (end - start) / (array.length - 1)
		
		for layer, i in array			
			if animate 
				layer.animate {"#{property}": start + (i * step)}
				continue
				
			layer[property] = start + (i * step)
	
	
	# arrange layers in an array into a grid, using a set number of columns and row/column margins
	# @example    Utils.grid(layers, 4)
	grid: (array = [], cols, rowMargin = 16, colMargin) ->
		
		g =
			x: array[0].x
			y: array[0].y
			cols: cols
			height: _.maxBy(array, 'height')?.height
			width: _.maxBy(array, 'width')?.width
			rowMargin: rowMargin ? 0
			columnMargin: colMargin ? rowMargin ? 0
			rows: []
			columns: []
			layers: []
			getLayer: (row, col) -> return @rows[row][col]
			getRandom: -> return _.sample(_.sample(@rows))
			push: (layer, i = @layers.length) ->
				
				if not layer
					layer = @layers[0].copySingle()
					layer.parent = @layers[0].parent
				
				col = i % cols
				row = Math.floor(i / cols)
				
				@rows[row] ?= [] 
				@rows[row].push(layer)
				
				@columns[col] ?= []
				@columns[col].push(layer)
				
				_.assign layer,
					x: @x + (col * (@width + @columnMargin))
					y: @y + (row * (@height + @rowMargin))
				
				@layers.push(layer)
				
				return layer
				
			pull: (layer) -> # buggy
				survivors = _.without(@layers, layer)
				
				@rows = []
				@columns = []
				@layers = []
				
				for sur, i in survivors
					@push(sur)
					
				return @
					
			apply: (func, layers = @layers) ->
				if not _.isArray(layers) then layers = [layers]
				
				for layer in layers
					Utils.build(layer, func)
		
		for layer, i in array
			g.push(layer, i)
				
		return g
	
	
	# make a grid out of a layer, copying the layer to fill rows
	# @example    Utils.makeGrid(layer, 2, 4, 8, 8)
	makeGrid: (layer, cols = 4, rows = 1, rowMargin, colMargin) ->
		layers = [layer]
		
		for i in _.range((cols * rows) - 1)
			layers[i + 1] = layer.copy()
			layers[i + 1].parent = layer.parent
			
		g = Utils.grid(layers, cols, rowMargin, colMargin)
		
		return g
	
	
	# set a layer to the max property among an array of layers (usually children)
	# @example    Utils.fit(layer, layer.children, 'maxY', 16)
	fitTo: (layer, array = [], property, padding = 0) ->
		
		
		return array
	

	fit: (layer, padding = 16) ->
		minX = (_.minBy(layer.children, 'x')?.x ? 0) + padding
		maxX = (_.maxBy(layer.children, 'maxX')?.maxX ? 0) + padding
		minY = (_.minBy(layer.children, 'y')?.y ? 0) + padding
		maxY = (_.maxBy(layer.children, 'maxY')?.maxY ? 0) + padding
		
		for child in layer.children
			child.x = _.clamp(padding + (child.x - minX), 0, Infinity)
			child.y = _.clamp(padding + (child.y - minY), 0, Infinity)

		_.assign layer,
			x: layer.x + minX
			y: layer.y + minY
			width: maxX - minX
			height: maxY - minY



	# get a status color based on a standard deviation
	# @example    Utils.getStatusColor(.04, false)
	getStatusColor: (dev, lowerBetter = false) ->
		
		colors = ['#ec4741', '#f48847', '#ffc84a', '#a7c54b', '#4fbf4f']
		
		if lowerBetter then dev = -dev
		
		color = Utils.modulate(dev, [-.1, 0.1], [0, colors.length - 1], false)
		
		return colors[color.toFixed()]
	
	
	# Chain an array of animations, optionally looping them
	# @example    Utils.chainAnimations([arrayOfAnimations], false)
	chainAnimations: (animations = [], looping = true) ->
		for anim, i in animations
			do (i, animations) ->
				if anim is _.last(animations) and looping
					anim.onAnimationEnd ->
						animations[0]?.start()
				
				anim.onAnimationEnd ->
					animations[i + 1]?.start()
			
		Utils.delay 0, -> animations[0].start()
		
		
		
		