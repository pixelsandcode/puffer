should = require('chai').should()
uuid   = require 'node-uuid'

host = 'localhost'
name = 'tipi'

describe 'Puffer', ->
  
  doc1Id = "puffer:#{uuid.v1()}"
  doc1   = { color: 'red' }
  doc2Id = "puffer:#{uuid.v1()}"
  doc2   = { color: 'blue' }
  doc3Id = "puffer:#{uuid.v1()}"
  doc3   = { color: 'green' }
  puffer = new require('../build/main') { host: host, name: name }, true 

  it "should create and get a document", ->
    puffer.create( doc1Id, doc1 )
      .then(
        (d) ->
          puffer.get( doc1Id )
            .then (d) ->
              d.should.be.an 'object'
              d.value.should.have.property('color').that.equals('red')
      )

  it "should get only value part of a document", ->
    puffer.get( doc1Id, true )
      .then (d) ->
        d.should.have.property('color').that.equals('red')
    
  it "should get only value part of multi documents", ->
    puffer.create( doc2Id, doc2 ).then(
      (d) ->
        puffer.get( [doc1Id, doc2Id], true )
          .then (d) ->
            d.should.eql [ { color: 'red' }, { color: 'blue' } ]
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
    puffer.remove( doc3Id )
      .then(
        (d) ->
          puffer.get( doc3Id )
            .then (d) ->
              d.output.should.have.deep.property('statusCode').that.equals(503)
      )

  it 'should update a document partially', ->
    id = 'u1'
    puffer.create( id, { name: 'Arash' } ).then(
      -> puffer.update( id, { age: 31 }).then(
          -> puffer.get(id).then (d) -> d.value.should.eql { name: 'Arash', age: 31 }
        )
    )
    id2 = 'u2'
    puffer.create( id2, { name: 'Jack' } ).then(
      -> puffer.update( id2, { name: 'Arash', age: 31 }).then(
          -> puffer.get(id2).then (d) -> d.value.should.eql { name: 'Arash', age: 31 }
        )
    )

  it 'should update a document based on passed method', ->
    id = 'u3'
    m = (doc) ->
      doc.age = 31
      doc.lastname = 'Smith'
      doc
    puffer.create( id, { name: 'Jack', age: 35 } ).then(
      -> puffer.update( id, m).then(
          -> puffer.get(id).then (d) -> d.value.should.eql { name: 'Jack', age: 31, lastname: 'Smith' }
        )
    )
