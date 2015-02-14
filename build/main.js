(function() {
  var Boom, CB, Couchbase, Database, Q, errorHandler, _;

  _ = require('lodash');

  CB = require('couchbase');

  Boom = require('boom');

  Q = require('q');

  errorHandler = function(ex) {
    return Boom.serverTimeout(ex.message);
  };

  Couchbase = (function() {
    function Couchbase(options, mock) {
      var cluster, host;
      host = options.port != null ? "" + options.host + ":" + options.port : options.host;
      cluster = (mock != null) && mock ? (console.log('Running mock Couchbase server...'), new CB.Mock.Cluster) : new CB.Cluster(host);
      this.bucket = cluster.openBucket(options.name);
    }

    Couchbase.prototype._exec = function(name) {
      return Q.npost(this.bucket, name, Array.prototype.slice.call(arguments, 1)).fail(errorHandler);
    };

    Couchbase.prototype.create = function(id, doc) {
      return this._exec("insert", id, doc);
    };

    Couchbase.prototype.get = function(id) {
      if (id.constructor === Array) {
        return this._exec("getMulti", id);
      } else {
        return this._exec("get", id);
      }
    };

    Couchbase.prototype.replace = function(id, doc) {
      return this._exec("replace", id, doc);
    };

    Couchbase.prototype.update = function(id, data) {
      var _this;
      _this = this;
      return this.get(id).then(function(d) {
        var doc;
        doc = d.value;
        if (_.isFunction(data)) {
          doc = data(doc);
        } else {
          _.extend(doc, data);
        }
        return _this.replace(id, doc);
      });
    };

    Couchbase.prototype.upsert = function(id, doc) {
      return this._exec("upsert", id, doc);
    };

    Couchbase.prototype.remove = function(id) {
      return this._exec("remove", id);
    };

    Couchbase.prototype.counter = function(id, step) {
      return this._exec("counter", id, step);
    };

    Couchbase.prototype.from = function(design, view) {
      return CB.ViewQuery.from(design, view);
    };

    Couchbase.prototype.commit = function(query) {
      return this._exec("query", query);
    };

    return Couchbase;

  })();

  module.exports = Database = (function() {
    Database.instance = null;

    function Database(options, mock) {
      Database.instance = new Couchbase(options, mock);
      return Database.instance;
    }

    return Database;

  })();

}).call(this);
