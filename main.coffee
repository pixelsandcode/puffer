CB = require 'couchbase'
Boom = require 'boom'

class Couchbase
  
  constructor: (options) ->
    host = if options.port? then "#{options.host}:#{options.port}" else options.host
    cluster = new CB.Cluster host
    @bucket = cluster.openBucket options.name
  
  _execute: (method) ->
    try
      args = Array.prototype.slice.call(arguments).slice(1)
      callback = args[args.length-1]
      args[args.length-1] = (err, data) ->
        if err
          callback Boom.badRequest err
        else
          callback data
      @bucket[method].apply @bucket, args
          
    catch ex
      console.log "[database] '#{method}' function caused this error."
      console.trace ex
      callback Boom.serverTimeout ex.message

  get: (id, callback) ->
    this._execute 'get', id, callback

  list: (design, view, callback) ->
    viewQuery = CB.ViewQuery
    query = viewQuery.from design, view
    this._execute 'query', query, callback

  create: (id, doc, callback) ->
    this._execute 'insert', id, doc, callback

module.exports = class Database
  
  @instance: null

  constructor: (options) ->
    Database.instance = new Couchbase options
    return Database.instance

