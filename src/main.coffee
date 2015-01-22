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
CB = require 'couchbase'
Boom = require 'boom'

Q = require('q')

errorHandler = (ex) ->
  Boom.serverTimeout ex.message
  
class Couchbase
  
  constructor: (options) ->
    host = if options.port? then "#{options.host}:#{options.port}" else options.host
    cluster = new CB.Cluster host
    @bucket = cluster.openBucket options.name
  
  # ## _exec( name, id, [doc])
  #
  # You should not call this. This is for puffers internal use.
  # 
  # @method 
  # @private
  #
  # @examples
  #   this._exec "insert", id, doc
  #   this._exec "get", id
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
    this._exec "insert", id, doc 

  # ## Get by id or ids
  #
  # This can get either an id or multiple ids (as an array) to retrieve document(s)
  # 
  # @examples
  #
  #   // Make sure you have stored 2 documents as 'doc1', 'doc2' in your couchbase
  #
  #   puffer.get('doc1').then( (d)-> console.log d )
  #   
  #   puffer.get(['doc1', 'doc2']).then( (d)-> console.log d )
  # 
  get: (id) ->
    return if id.constructor == Array
      this._exec "getMulti", id
    else
      this._exec "get", id

  # ## Replace a document
  #
  # Replace an existing document with a new one
  # 
  # @examples
  #
  #   puffer.replace('doc1').then( (d)-> console.log d )
  #
  replace: (id, doc) ->
    this._exec "replace", id, doc

  # ## Create or Replace a document
  #
  # Replace an existing document with a new one
  # 
  # @examples
  #
  #   puffer.upsert('doc1', { color: 'blue' }).then( (d)-> console.log d )
  #
  upsert: (id, doc) ->
    this._exec "upsert", id, doc

  # ## Remove a document
  #
  # Remove an existing document
  # 
  # @examples
  #
  #   puffer.remove('doc1').then( (d)-> console.log d )
  #
  remove: (id) ->
    this._exec "remove", id

  # ## Atomic Counter 
  #
  # Atomic increase/decrease a counter 
  # 
  # @examples
  #
  #   puffer.counter('doc1', 1).then( (d)-> console.log d )
  #
  counter: (id, step) ->
    this._exec "counter", id, step

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
    this._exec "query", query

module.exports = class Database
  
  @instance: null

  constructor: (options) ->
    Database.instance = new Couchbase options
    return Database.instance

