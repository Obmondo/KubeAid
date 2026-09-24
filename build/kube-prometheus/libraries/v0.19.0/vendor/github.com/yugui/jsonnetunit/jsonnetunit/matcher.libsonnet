{
  satisfied: error 'must implement satisfied in concrete matcher',
  positiveMessage: error 'must implement positiveMessage in concrete matcher',
  negativeMessage: error 'must implement negativeMessage in concreteMatcher',

  matches(expectationType):: self.satisfied == expectationType,
  message(expectationType)::
    if expectationType then
      self.positiveMessage
    else
      self.negativeMessage,
}
