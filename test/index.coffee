chai = require 'chai'

describe 'Experiences', ->
  describe '#index', ->
    it "Should list 10 experiences, sorted by time within next 20 hours."
    it "Should not get listed if it is a passed."
    it "Should not get listed if it is capped."
    it "Should have image, title, when and maybe voucher."

  describe '#show', ->
    it "Should show all its images if it has more than one image"
    it "Should list all attendees for next occurrence"
    it "Should have a description"
     
