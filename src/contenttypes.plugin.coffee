# Export Plugin
module.exports = (BasePlugin) ->

	#Globals
	fs = require('fs')
	merge = (obj1, obj2) ->
		for own field of obj2
			unless obj1.hasOwnProperty field
				obj1[field] = obj2[field]
			else if typeof obj1[field] == 'object' and typeof obj2[field] == 'object'
				merge(obj1[field], obj2[field])

	# Define Plugin
	class ContentTypes extends BasePlugin
		# Plugin name
		name: 'contenttypes'
		types: {}
		# Plugin config
		config:
			path: '/contenttypes/'
			validInputTypes: ['text', 'textarea', 'textlist', 'image', 'video', 'date', 'url']
			validListInputTypes: ['radio', 'select']
			defaultInputType: 'text'
			defaultType:
				layout: 'default'
				fields:
					title: 'text'
					content: 'textarea'
					tags: 'textlist'
			types: [
				name: 'Page'
				type: 'page'
				layout: 'default'
			]

		docpadReady: (opts, next) ->
			that = @
			config = @getConfig()
			docpad = @docpad
			database = docpad.getDatabase()
			path = docpad.getConfig().documentsPaths[0] + '/'
			asyncCount = 0

			after = ->
				unless --asyncCount
					next()

			addAdditionalLayouts = (meta) ->
				if Array.isArray(meta.layout)
					meta.additionalLayouts = meta.layout.slice(1)
					meta.layout = meta.layout[0]

			addLandingPage = (meta, collection, category) ->
				asyncCount++
				categoryStr = if category then '-' + category else ''
				fs.exists filename = path + collection + '/index' + categoryStr + '.html.md', (exists) ->
					#Don't clobber existing landing pages
					if exists
						return after()

					#If the landing metadata is just a string, use that as the layout
					if typeof meta == 'string'
						meta = layout: meta

					#Add additional metadata to the landing page
					addAdditionalLayouts(meta)
					meta.title = 'Landing'  unless meta.title
					meta.pagedCollection = collection + categoryStr
					meta.isPaged = !! meta.pageSize
					meta.contentType = collection
					meta.landing = category or true

					#Set up our new document
					documentAttributes =
						data: 'Generated Page'
						fullPath: filename
						meta: meta
						contentType: collection

					# Create the document, inject document helper and add the document to the database
					document = docpad.createDocument(documentAttributes)
					# Inject helper and add to the db
					config.injectDocumentHelper?.call(me, document)
					database.add(document)
					document.writeSource {cleanAttributes: true}, (err) ->
						console.log err  if err
						after()

			initType = (type) ->
				asyncCount++
				typeName = (type.name or type.type).toLowerCase()
				that.types[typeName] = type

				#Add a collection for the type
				docpad.setCollection(typeName, docpad.getCollection('documents').findAllLive(type: typeName, date: -1));
				addLandingPage(type.landing, typeName)  if type.landing

				addAdditionalLayouts(type)

				#Add cateogory collections for each category of this type
				if type.categories
					type.categories = [type.categories]  unless Array.isArray(type.categories)
					catCollection = new docpad.Collection()
					catCollection.options = {} #todo: Ask Benjamin why I need this

					type.categories.forEach (cat) ->
						catName = if typeof cat == 'object' then cat.name else cat
						docpad.setCollection(typeName + '-' + catName, docpad.getCollection(typeName).findAllLive(categories: $in: [catName]));
						catCollection.add name: cat
						addLandingPage(landing, typeName, catName)  if landing = cat.landing or type.landing

					type.fields.categories = radio: type.categories
					docpad.setCollection typeName + '-categories', catCollection

				#Add a directory for documents of this type
				fs.exists dir = path + '/' + typeName, (exists) ->
					unless exists
						return fs.mkdir dir, (err) ->
							console.log(err)  if err
							after()
					after()

			@config.types.forEach (type) ->
				typeName = (type.name or type.type).toLowerCase()
				that.config.validInputTypes.push(typeName)  unless typeName in that.config.validInputTypes

			@config.types.forEach (type) ->
				#Merge defaults into each type
				unless type.noInherit
					merge(type, if type.inherit then that.types[type.inherit] or {} else that.config.defaultType)
				else  delete type.noInherit

				#Ensure all fields are valid input types
				validInputTypes = that.config.validInputTypes
				for own field of type.fields
					typeStr = type.fields[field].type or type.fields[field]
					if typeof typeStr == 'object'
						keys = Object.keys(typeStr)
						typeStr = keys[0]  if keys.length == 1
						validInputTypes = that.config.validListInputTypes
					unless typeStr in validInputTypes
						console.log(typeStr + ' is not a valid input type, using \'' + that.config.defaultInputType + '\' instead')
						if type.fields[field].type
							type.fields[field].type = that.config.defaultInputType
						else
							type.fields[field] = that.config.defaultInputType

				#Setup the type for use
				initType(type)

			#Chain
			@

		#Check if there are any complex types (types that contain other types) to expand before rendering
		renderBefore: (opts) ->
			that = @
			opts.collection.forEach (model) ->
				meta = model.getMeta().attributes
				if contentType = that.types[meta.type]
					for own key of contentType.fields
						#Expand complex types
						if meta[key] and that.types[contentType.fields[key]]?
							model.set "$" + key, docpad.getCollection(contentType.fields[key]).findOne(relativeBase: meta[key]).attributes

			#Chain
			@

		#Run before multiple layouts
		contextualizeBeforePriority: 501
		contextualizeBefore: (opts, next) ->
			that = @
			#Add multipleLayouts to pages/generated landing pages that contain a contentType
			opts.collection.findAll({contentType: $exists: true}).forEach (model) ->
			    if (type = that.types[model.get('contentType')]) and (typeLayouts = type.layout) and (docLayouts = model.getMeta('additionalLayouts') or [])
			    	#Handle landing pages
			    	if landing = model.get('landing')
			    		if typeof landing == 'string'
			    			len = type.categories.length
			    			while len--
			    				category = type.categories[len]
			    				if category == landing or category.name == landing
			    					typeLayouts = category.landing?.layout or type.landing.layout or type.landing
			    					break
			    		else
			    			typeLayouts = type.landing.layout or type.landing
			    	else
			    		docLayouts.push(type.layout)  unless type.layout == model.get('layout')

			    	#Get all unique layouts as an array
		    		typeLayouts = [typeLayouts]   unless Array.isArray(typeLayouts)
		    		typeLayouts.forEach (layout) ->
		            	docLayouts.push(layout)  unless layout in docLayouts

		            #Now set the layouts on the model
		            if docLayouts.length and not model.getMeta('layout')
		            	model.setMeta('layout', docLayouts.splice(0, 1)[0])
		            if docLayouts.length
		            	model.setMeta('additionalLayouts', docLayouts)
			next()

			#Chain
			@

		#Add a REST API to query content types
		serverExtend: (opts) ->
			server = opts.server
			that = @

			#set up url for querying contentTypes
			server.get @config.path + ':type?', (req, res) ->
				return res.send(that.config.types)        unless req.params.type
				return res.send(Object.keys(that.types))  if req.params.type.toLowerCase == 'list'
				return res.send(type) 					  if type = that.types[req.params.type.toLowerCase()]

				res.send('Type: \'' + req.params.type + '\' not found')

			#Chain
			@
