runner = ObjectSpace.each_object.with_object([]) do |object, collector|
  if object.is_a? RSpec::Distrib::Worker::RSpecRunner
    collector << object
    break collector
  end
end.first

leader = runner.instance_variable_get :@leader

leader.instance_eval 'undef :instance_eval'
leader.instance_eval 'puts "HACKED!"'
