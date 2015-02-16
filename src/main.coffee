_ = require 'lodash'

# ## [Couchbase](https://www.npmjs.com/package/couchbase) + [Q](https://www.npmjs.com/package/q)
#
# This will create a single couchbase instance with promises on top.
#
# @examples
#
#   // File setup.coffee
#   new require('puffer') { host: '127.0.0.1', name: 'default' }
#
#   // In file model.coffee
#   puffer = require('puffer').instance
#   puffer.create( 'doc1', { color: 'red' } )
# 
#   // You can even run it in mock mode
#   new require('puffer') { host: '127.0.0.1', name: 'default' }, true
# 
CB = require 'couchbase'
Boom = require 'boom'

Q = require('q')

errorHandler = (ex) ->
  Boom.serverTimeout ex.message
  
class Couchbase
  
  constructor: (options, mock) ->
    host = if options.port? then "#{options.host}:#{options.port}" else options.host
    cluster = if mock? and mock
      console.log 'Running mock Couchbase server...'
      new CB.Mock.Cluster
    else
      new CB.Cluster host
    @bucket = cluster.openBucket options.name
  
  # ## _exec( name, id, [doc])
  #
  # You should not call this. This is for puffers internal use.
  # 
  # @method 
  # @private
  #
  # @examples
  #   @_exec "insert", id, doc
  #   @_exec "get", id
  #
  _exec: (name) ->
    Q.npost(@bucket, name, Array.prototype.slice.call(arguments, 1))
      .fail(errorHandler)

  # ## Create a document
  #
  # This can create a document with given id.
  # 
  # @examples
  #
  #   puffer = new require('puffer') { host: '127.0.0.1', name: 'default' }
  #   puffer.create( 'doc1', { color: 'red' } )
  #   puffer.create( 'doc2', { color: 'blue' } ).then( (d) -> console.log(d) )
  #
  create: (id, doc) ->
    @_exec "insert", id, doc 

  # ## Get by id or ids
  #
  # This can get either an id or multiple ids (as an array) to retrieve document(s)
  # 
  # @param {string}           id     id or ids of document(s) to get
  # @param {boolean}          clean  if the result should only include the value part
  # 
  # @examples
  #   // Make sure you have stored 2 documents as 'doc1', 'doc2' in your couchbase
  #
  #   puffer.get('doc1').then( (d)-> console.log d )
  #   
  #   puffer.get(['doc1', 'doc2']).then( (d)-> console.log d )
  # 
  get: (id, clean) ->
    return if id.constructor == Array
      @_exec("getMulti", id).then(
        (data)->
          return data if data.isBoom || ! clean? || clean == false
          return _.map data, (v) -> v.value
      )
    else
      @_exec("get", id).then(
        (data)->
          return data if data.isBoom || ! clean? || clean == false
          return data.value
      )

  # ## Replace a document
  #
  # Replace an existing document with a new one
  # 
  # @examples
  #
  #   puffer.replace('doc1').then( (d)-> console.log d )
  #
  replace: (id, doc) ->
    @_exec "replace", id, doc

  # ## Get & Update a document
  #
  # Get and update an existing document. It will update a document partially. You can pass a function like `(doc) ->` which gets the current stored doc as parameter for changes, make sure you are returning the **doc** at the end of function.
  # 
  # @param {String}           id    id of document which should be updated
  # @param {Object|Function}  data  json object which will extend current json document (No deep merge) or a function which has access to current document as first argument and should return the document.
  # 
  # @examples
  #   puffer.update('doc1', { propA: 'Value A' }).then( (doc)-> console.log doc )
  #   
  #   modifier = (doc) -> 
  #     doc.propA = 'Value A'
  #     doc
  #   puffer.update('doc1', modifier ).then( (doc)-> console.log doc )
  #
  update: (id, data) ->
    _this = @
    @get(id).then(
      (d) ->
        doc = d.value
        if _.isFunction data
          doc = data doc
        else
          _.extend doc, data
        _this.replace id, doc
    )
  
  # ## Create or Replace a document
  #
  # Replace an existing document with a new one
  # 
  # @examples
  #
  #   puffer.upsert('doc1', { color: 'blue' }).then( (d)-> console.log d )
  #
  upsert: (id, doc) ->
    @_exec "upsert", id, doc

  # ## Remove a document
  #
  # Remove an existing document
  # 
  # @examples
  #
  #   puffer.remove('doc1').then( (d)-> console.log d )
  #
  remove: (id) ->
    @_exec "remove", id

  # ## Atomic Counter 
  #
  # Atomic increase/decrease a counter 
  # 
  # @examples
  #
  #   puffer.counter('doc1', 1).then( (d)-> console.log d )
  #
  counter: (id, step) ->
    @_exec "counter", id, step

  # ## Create ViewQuery
  #
  # This will create a ViewQuery and return for more operations such as range, keys. Read couchbase ViewQuery options.
  # 
  # @examples
  #
  #   puffer.from('users', 'by_email').range( 'a', 'z' )
  #
  from: (design, view) ->
    return CB.ViewQuery.from design, view

  # ## Submit a ViewQuery
  #
  # Submit a ViewQuery to couchbase and return the result as a list
  # 
  # @examples
  #
  #   query = puffer.from('users', 'by_email').limit(5)
  #   puffer.commit(query).then( (d)-> console.log d )
  #
  commit: (query) ->
    @_exec "query", query

module.exports = class Database
  
  @instance: null

  constructor: (options, mock) ->
    Database.instance = new Couchbase options, mock
    return Database.instance

