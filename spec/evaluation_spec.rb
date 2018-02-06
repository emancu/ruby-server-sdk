require "spec_helper"

describe LaunchDarkly::Evaluation do
  subject { LaunchDarkly::Evaluation }
  let(:features) { LaunchDarkly::InMemoryFeatureStore.new }

  include LaunchDarkly::Evaluation

  describe "evaluate" do
    it "returns off variation if flag is off" do
      flag = {
        key: 'feature',
        on: false,
        offVariation: 1,
        fallthrough: { variation: 0 },
        variations: ['a', 'b', 'c']
      }
      user = { key: 'x' }
      expect(evaluate(flag, user, features)).to eq({value: 'b', events: []})
    end

    it "returns nil if flag is off and off variation is unspecified" do
      flag = {
        key: 'feature',
        on: false,
        fallthrough: { variation: 0 },
        variations: ['a', 'b', 'c']
      }
      user = { key: 'x' }
      expect(evaluate(flag, user, features)).to eq({value: nil, events: []})
    end

    it "returns off variation if prerequisite is not found" do
      flag = {
        key: 'feature0',
        on: true,
        prerequisites: [{key: 'badfeature', variation: 1}],
        fallthrough: { variation: 0 },
        offVariation: 1,
        variations: ['a', 'b', 'c']
      }
      user = { key: 'x' }
      expect(evaluate(flag, user, features)).to eq({value: 'b', events: []})
    end

    it "returns off variation and event if prerequisite is not met" do
      flag = {
        key: 'feature0',
        on: true,
        prerequisites: [{key: 'feature1', variation: 1}],
        fallthrough: { variation: 0 },
        offVariation: 1,
        variations: ['a', 'b', 'c'],
        version: 1
      }
      flag1 = {
        key: 'feature1',
        on: true,
        fallthrough: { variation: 0 },
        variations: ['d', 'e'],
        version: 2
      }
      features.upsert('feature1', flag1)
      user = { key: 'x' }
      events_should_be = [{kind: 'feature', key: 'feature1', value: 'd', version: 2, prereqOf: 'feature0'}]
      expect(evaluate(flag, user, features)).to eq({value: 'b', events: events_should_be})
    end

    it "returns fallthrough variation and event if prerequisite is met and there are no rules" do
      flag = {
        key: 'feature0',
        on: true,
        prerequisites: [{key: 'feature1', variation: 1}],
        fallthrough: { variation: 0 },
        offVariation: 1,
        variations: ['a', 'b', 'c'],
        version: 1
      }
      flag1 = {
        key: 'feature1',
        on: true,
        fallthrough: { variation: 1 },
        variations: ['d', 'e'],
        version: 2
      }
      features.upsert('feature1', flag1)
      user = { key: 'x' }
      events_should_be = [{kind: 'feature', key: 'feature1', value: 'e', version: 2, prereqOf: 'feature0'}]
      expect(evaluate(flag, user, features)).to eq({value: 'a', events: events_should_be})
    end

    it "matches user from targets" do
      flag = {
        key: 'feature0',
        on: true,
        targets: [
          { values: [ 'whoever', 'userkey' ], variation: 2 }
        ],
        fallthrough: { variation: 0 },
        offVariation: 1,
        variations: ['a', 'b', 'c']
      }
      user = { key: 'userkey' }
      expect(evaluate(flag, user, features)).to eq({value: 'c', events: []})
    end

    it "matches user from rules" do
      flag = {
        key: 'feature0',
        on: true,
        rules: [
          {
            clauses: [
              {
                attribute: 'key',
                op: 'in',
                values: [ 'userkey' ]
              }
            ],
            variation: 2
          }
        ],
        fallthrough: { variation: 0 },
        offVariation: 1,
        variations: ['a', 'b', 'c']
      }
      user = { key: 'userkey' }
      expect(evaluate(flag, user, features)).to eq({value: 'c', events: []})
    end
  end

  describe "clause_match_user" do
    it "can match built-in attribute" do
      user = { key: 'x', name: 'Bob' }
      clause = { attribute: 'name', op: 'in', values: ['Bob'] }
      expect(clause_match_user(clause, user)).to be true
    end

    it "can match custom attribute" do
      user = { key: 'x', name: 'Bob', custom: { legs: 4 } }
      clause = { attribute: 'legs', op: 'in', values: [4] }
      expect(clause_match_user(clause, user)).to be true
    end

    it "returns false for missing attribute" do
      user = { key: 'x', name: 'Bob' }
      clause = { attribute: 'legs', op: 'in', values: [4] }
      expect(clause_match_user(clause, user)).to be false
    end

    it "can be negated" do
      user = { key: 'x', name: 'Bob' }
      clause = { attribute: 'name', op: 'in', values: ['Bob'], negate: true }
      expect(clause_match_user(clause, user)).to be false
    end
  end

  describe "operators" do
    dateStr1 = "2017-12-06T00:00:00.000-07:00"
    dateStr2 = "2017-12-06T00:01:01.000-07:00"
    dateMs1 = 10000000
    dateMs2 = 10000001
    invalidDate = "hey what's this?"

    operatorTests = [
      # numeric comparisons
      [ :in,                 99,      99,      true ],
      [ :in,                 99.0001, 99.0001, true ],
      [ :in,                 99,      99.0001, false ],
      [ :in,                 99.0001, 99,      false ],
      [ :lessThan,           99,      99.0001, true ],
      [ :lessThan,           99.0001, 99,      false ],
      [ :lessThan,           99,      99,      false ],
      [ :lessThanOrEqual,    99,      99.0001, true ],
      [ :lessThanOrEqual,    99.0001, 99,      false ],
      [ :lessThanOrEqual,    99,      99,      true ],
      [ :greaterThan,        99.0001, 99,      true ],
      [ :greaterThan,        99,      99.0001, false ],
      [ :greaterThan,        99,      99,      false ],
      [ :greaterThanOrEqual, 99.0001, 99,      true ],
      [ :greaterThanOrEqual, 99,      99.0001, false ],
      [ :greaterThanOrEqual, 99,      99,      true ],

      # string comparisons
      [ :in,         "x",   "x",   true ],
      [ :in,         "x",   "xyz", false ],
      [ :startsWith, "xyz", "x",   true ],
      [ :startsWith, "x",   "xyz", false ],
      [ :endsWith,   "xyz", "z",   true ],
      [ :endsWith,   "z",   "xyz", false ],
      [ :contains,   "xyz", "y",   true ],
      [ :contains,   "y",   "xyz", false ],

      # mixed strings and numbers
      [ :in,                 "99", 99, false ],
      [ :in,                  99, "99", false ],
      #[ :contains,           "99", 99, false ],    # currently throws exception - would return false in Java SDK
      #[ :startsWith,         "99", 99, false ],  # currently throws exception - would return false in Java SDK
      #[ :endsWith,           "99", 99, false ]     # currently throws exception - would return false in Java SDK
      [ :lessThanOrEqual,    "99", 99, false ],
      #[ :lessThanOrEqual,    99, "99", false ],    # currently throws exception - would return false in Java SDK
      [ :greaterThanOrEqual, "99", 99, false ],
      #[ :greaterThanOrEqual, 99, "99", false ], # currently throws exception - would return false in Java SDK
      
      # regex
      [ :matches, "hello world", "hello.*rld",     true ],
      [ :matches, "hello world", "hello.*orl",     true ],
      [ :matches, "hello world", "l+",             true ],
      [ :matches, "hello world", "(world|planet)", true ],
      [ :matches, "hello world", "aloha",          false ],
      #[ :matches, "hello world", "***not a regex", false ]   # currently throws exception - same as Java SDK

      # dates
      [ :before, dateStr1, dateStr2,    true ],
      [ :before, dateMs1,  dateMs2,     true ],
      [ :before, dateStr2, dateStr1,    false ],
      [ :before, dateMs2,  dateMs1,     false ],
      [ :before, dateStr1, dateStr1,    false ],
      [ :before, dateMs1,  dateMs1,     false ],
      [ :before, dateStr1, invalidDate, false ],
      [ :after,  dateStr1, dateStr2,    false ],
      [ :after,  dateMs1,  dateMs2,     false ],
      [ :after,  dateStr2, dateStr1,    true ],
      [ :after,  dateMs2,  dateMs1,     true ],
      [ :after,  dateStr1, dateStr1,    false ],
      [ :after,  dateMs1,  dateMs1,     false ],
      [ :after,  dateStr1, invalidDate, false ],

      # semver
      [ :semVerEqual,       "2.0.1", "2.0.1", true ],
      [ :semVerEqual,       "2.0",   "2.0.0", true ],
      [ :semVerEqual,       "2-rc1", "2.0.0-rc1", true ],
      [ :semVerEqual,       "2+build2", "2.0.0+build2", true ],
      [ :semVerLessThan,    "2.0.0", "2.0.1", true ],
      [ :semVerLessThan,    "2.0",   "2.0.1", true ],
      [ :semVerLessThan,    "2.0.1", "2.0.0", false ],
      [ :semVerLessThan,    "2.0.1", "2.0",   false ],
      [ :semVerLessThan,    "2.0.0-rc", "2.0.0-rc.beta", true ],
      [ :semVerGreaterThan, "2.0.1", "2.0.0", true ],
      [ :semVerGreaterThan, "2.0.1", "2.0",   true ],
      [ :semVerGreaterThan, "2.0.0", "2.0.1", false ],
      [ :semVerGreaterThan, "2.0",   "2.0.1", false ],
      [ :semVerGreaterThan, "2.0.0-rc.1", "2.0.0-rc.0", true ],
      [ :semVerLessThan,    "2.0.1", "xbad%ver", false ],
      [ :semVerGreaterThan, "2.0.1", "xbad%ver", false ]
    ]

    operatorTests.each do |params|
      op = params[0]
      value1 = params[1]
      value2 = params[2]
      shouldBe = params[3]
      it "should return #{shouldBe} for #{value1} #{op} #{value2}" do
        user = { key: 'x', custom: { foo: value1 } }
        clause = { attribute: 'foo', op: op, values: [value2] }
        expect(clause_match_user(clause, user)).to be shouldBe
      end
    end
  end

  describe "bucket_user" do
    it "gets expected bucket values for specific keys" do
      user = { key: "userKeyA" }
      bucket = bucket_user(user, "hashKey", "key", "saltyA")
      expect(bucket).to be_within(0.0000001).of(0.42157587);

      user = { key: "userKeyB" }
      bucket = bucket_user(user, "hashKey", "key", "saltyA")
      expect(bucket).to be_within(0.0000001).of(0.6708485);

      user = { key: "userKeyC" }
      bucket = bucket_user(user, "hashKey", "key", "saltyA")
      expect(bucket).to be_within(0.0000001).of(0.10343106);
    end

    it "can bucket by int value (equivalent to string)" do
      user = {
        key: "userkey",
        custom: {
          stringAttr: "33333",
          intAttr: 33333
        }
      }
      stringResult = bucket_user(user, "hashKey", "stringAttr", "saltyA")
      intResult = bucket_user(user, "hashKey", "intAttr", "saltyA")

      expect(intResult).to be_within(0.0000001).of(0.54771423)
      expect(intResult).to eq(stringResult)
    end

    it "cannot bucket by float value" do
      user = {
        key: "userkey",
        custom: {
          floatAttr: 33.5
        }
      }
      result = bucket_user(user, "hashKey", "floatAttr", "saltyA")
      expect(result).to eq(0.0)
    end


    it "cannot bucket by bool value" do
      user = {
        key: "userkey",
        custom: {
          boolAttr: true
        }
      }
      result = bucket_user(user, "hashKey", "boolAttr", "saltyA")
      expect(result).to eq(0.0)
    end
  end
end
