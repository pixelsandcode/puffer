(function() {
  var Boom, CB, Couchbase, Database, Q, _, errorHandler;

  _ = require('lodash');

  // ## [Couchbase](https://www.npmjs.com/package/couchbase) + [Q](https://www.npmjs.com/package/q)

  // This will create a single couchbase instance with promises on top.

  // @examples

  //   // File setup.coffee
  //   new require('puffer') { host: '127.0.0.1', name: 'default' }
  //   new require('puffer') { host: '127.0.0.1', name: 'analytics' }

  //   // In file model.coffee
  //   puffer = require('puffer').instances['default']
  //   puffer.insert( 'doc1', { color: 'red' } )

  //   // In file analytic.coffee
  //   puffer = require('puffer').instances['analytics']
  //   puffer.insert( 'doc1', { total_hits: 10 } )

  //   // You can even run it in mock mode
  //   new require('puffer') { host: '127.0.0.1', name: 'default' }, true

  CB = require('couchbase');

  Boom = require('boom');

  Q = require('q');

  errorHandler = function(ex) {
    return Boom.serverUnavailable(ex.message);
  };

  Couchbase = class Couchbase {
    // ## Create a puffer instance

    // You cannot call this constructor directly as it is singleton. Check above for examples.

    // @param {object}  options     it includes bucket name to connect to, host and port or you can pass all as host. e.g. { host: 'localhost', port: 8200, name: 'default' } or { host: '//couchbase', name: 'default' } or { host: 'localhost', name: 'main', password: '123', callback: fn }
    // @param {boolean} mock        if you want to have mock server pass true.

    constructor(options, mock) {
      var cluster, host, params;
      host = options.port != null ? `${options.host}:${options.port}` : options.host;
      cluster = (mock != null) && mock ? new CB.Mock.Cluster : new CB.Cluster(host);
      params = [options.name];
      if (options.password) {
        params.push(options.password);
      }
      if (options.callback) {
        params.push(options.callback);
      }
      this.bucket = cluster.openBucket.apply(cluster, params);
    }

    // ## _exec( name, key, [doc])

    // You should not call this directly in your code. This is for puffer's internal use.

    // @method
    // @private

    // @param {string}           name     name of couchbase method to be called. Rest of passed params will be passed to couchbase method as arguments.

    // @examples
    //   @_exec "insert", key, doc
    //   @_exec "get", key

    _exec(name) {
      return Q.npost(this.bucket, name, Array.prototype.slice.call(arguments, 1)).fail(errorHandler);
    }

    // ## Create a document

    // This can create a document with the given key only if the key doesn't exist.

    // @param {string}       key       document name. This can be used to get the document back.
    // @param {document}     doc       json object, string or integer which should be saved with the given key.
    // @param {object}       options   same as couchbase options for [insert](http://docs.couchbase.com/sdk-api/couchbase-node-client-2.0.8/Bucket.html#insert)

    // @examples

    //   puffer = new require('puffer') { host: '127.0.0.1', name: 'default' }
    //   puffer.insert( 'doc1', { color: 'red' } )
    //   puffer.insert( 'doc2', { color: 'blue' } ).then( (d) -> console.log(d) )

    insert(key, doc, options) {
      options || (options = {});
      return this._exec("insert", key, doc, options);
    }

    // ## Get by key or keys

    // This can get a document based on a key. Or get documents if you pass an array of keys.

    // @param {string | array}   key     key or keys of document(s) to get
    // @param {boolean}          clean   if it is true, it will only return the value part of result

    // @method get(key, [clean=true])
    // @public

    // @examples
    //   // Make sure you have stored 2 documents as 'doc1', 'doc2' in your couchbase

    //   puffer.get('doc1').then( (d)-> console.log d )

    //   puffer.get(['doc1', 'doc2']).then( (d)-> console.log d )

    get(key, clean) {
      if (key.constructor === Array) {
        return this._exec("getMulti", key).then(function(data) {
          if (data.isBoom || (clean == null) || clean === false) {
            return data;
          }
          return _.map(data, function(v) {
            return v.value;
          });
        });
      } else {
        return this._exec("get", key).then(function(data) {
          if (data.isBoom || (clean == null) || clean === false) {
            return data;
          }
          return data.value;
        });
      }
    }

    // ## Replace a document

    // Replace an existing document with a new one

    // @param {string}    key       key of document which should be replaced
    // @param {document}  doc       json object, string or integer which should be saved with the given key.
    // @param {object}    options   same as couchbase options for [replace](http://docs.couchbase.com/sdk-api/couchbase-node-client-2.0.8/Bucket.html#replace)

    // @examples

    //   puffer.replace('doc1').then( (d)-> console.log d )
    //   puffer.replace('doc1', { cas: { '0': 1927806976, '1': 2727156638 } } ).then( (d)-> console.log d )

    replace(key, doc, options) {
      options || (options = {});
      return this._exec("replace", key, doc, options);
    }

    // ## Get & Update a document

    // Get and update an existing document. It will update a document partially. You can pass a function like `(doc) ->` which gets the current stored doc as parameter for changes, make sure you are returning the **doc** at the end of function.

    // @param {string}           key      key of document which should be updated
    // @param {object|function}  data     json object which will extend current json document (No deep merge) or a function which has access to current document as first argument and should return the document.
    // @param {Boolean}          withCas  if true, it will add CAS in replace method

    // @examples
    //   puffer.update('doc1', { propA: 'Value A' }).then( (doc)-> console.log doc )

    //   modifier = (doc) ->
    //     doc.year = 2000
    //     doc
    //   puffer.update('doc1', modifier ).then (doc)->
    //     console.log doc
    //     doc.year = 2001
    //     doc

    update(key, data, withCas) {
      var _this;
      _this = this;
      return this.get(key).then(function(d) {
        var doc;
        doc = d.value;
        if (_.isFunction(data)) {
          doc = data(doc);
        } else {
          _.extend(doc, data);
        }
        return _this.replace(key, doc, {
          cas: d.cas
        });
      });
    }

    // ## Create or Replace a document

    // Replace an existing document with a new one

    // @param {string}    key       key of document which should be inserted or updated
    // @param {document}  doc       json object, string or integer which should be saved with the given key.
    // @param {object}    options   same as couchbase options for [upsert](http://docs.couchbase.com/sdk-api/couchbase-node-client-2.0.8/Bucket.html#upsert)

    // @examples

    //   puffer.upsert('doc1', { color: 'blue' }).then( (d)-> console.log d )

    upsert(key, doc, options) {
      options || (options = {});
      return this._exec("upsert", key, doc, options);
    }

    // ## Remove a document

    // Remove an existing document

    // @param {string}    key       key of document which should be removed
    // @param {object}    options   same as couchbase options for [remove](http://docs.couchbase.com/sdk-api/couchbase-node-client-2.0.8/Bucket.html#remove)

    // @examples

    //   puffer.remove('doc1').then( (d)-> console.log d )

    remove(key, options) {
      options || (options = {});
      return this._exec("remove", key, options);
    }

    // ## Atomic Counter

    // Atomic increase/decrease a counter. If the counter doesn't exist and you pass **initial** in options it will create the counter with intial value.

    // @param {string}    key       key of document which should be removed
    // @param {integer}   delta     the amount to add or subtract from the counter value. This value may be any non-zero integer.
    // @param {object}    options   same as couchbase options for [counter](http://docs.couchbase.com/sdk-api/couchbase-node-client-2.0.8/Bucket.html#counter)

    // @examples

    //   puffer.counter('doc1', 1, { initial: 5}).then( (d)-> console.log d )

    counter(key, delta, options) {
      options || (options = {});
      return this._exec("counter", key, delta, options);
    }

    // ## Create ViewQuery

    // This will create a ViewQuery and return for more operations such as range, keys. Read couchbase (ViewQuery)[http://docs.couchbase.com/sdk-api/couchbase-node-client-2.0.8/ViewQuery.html] object to understand how you can use it.

    // @param {string}   design   the design name to look up.
    // @param {string}   view     the view name to use for query.

    // @examples

    //   puffer.from('users', 'by_email').range( 'a', 'z' )

    from(design, view) {
      return CB.ViewQuery.from(design, view);
    }

    // ## Submit a ViewQuery

    // Submit a ViewQuery to couchbase and return the result as a list

    // @param {ViewQuery}   query

    // @examples

    //   query = puffer.from('users', 'by_email').limit(5)
    //   puffer.commit(query).then( (d)-> console.log d )

    commit(query) {
      return this._exec("query", query);
    }

  };

  module.exports = Database = (function() {
    class Database {
      constructor(options, mock) {
        Database.instances[options.name] = new Couchbase(options, mock);
        return Database.instances[options.name];
      }

    };

    Database.instances = [];

    return Database;

  }).call(this);

}).call(this);
