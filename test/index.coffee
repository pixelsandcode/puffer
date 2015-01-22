should = require('chai').should()
uuid   = require 'node-uuid'

host = 'localhost'
name = 'tipi'

describe 'Puffer', ->
  
  doc1Id = "puffer:#{uuid.v1()}"
  doc1   = { color: 'red' }
  doc2Id = "puffer:#{uuid.v1()}"
  doc2   = { color: 'blue' }
  puffer = new require('../build/main')( { host: host, name: name } )

  it "should create and get a document", ->
    puffer.create( doc1Id, doc1 )
      .then(
        (d) ->
          puffer.get( doc1Id )
            .then (d) ->
              d.should.be.an 'object'
              d.value.should.have.property('color').that.equals('red')
      )
    
  it 'should replace a document with a new one', ->
    puffer.replace( doc1Id, { city: 'Tehran' } )
      .then(
        (d) ->
          puffer.get( doc1Id )
            .then (d) ->
              d.should.be.an 'object'
              d.value.should.have.property('city').that.equals('Tehran')
      )
    
  it 'should delete a document', ->
    puffer.remove( doc1Id )
      .then(
        (d) ->
          puffer.get( doc1Id )
            .then (d) ->
              d.output.should.have.deep.property('statusCode').that.equals(503)
      )
    puffer.remove( doc2Id )
      .then(
        (d) ->
          puffer.get( doc2Id )
            .then (d) ->
              d.output.should.have.deep.property('statusCode').that.equals(503)
      )
      
