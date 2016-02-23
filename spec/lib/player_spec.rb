require "support/fakes/body"
require "support/fakes/shape"
require "support/shared_examples/it_moves_on_the_boundary_of_a_ball"

require "player"

RSpec.describe Player do
  it_behaves_like "it moves on the boundary of a ball" do
    let(:position) { CP::Vec2.new(400, 300) }
    let(:body) { FakeBody.new(position) }
    let(:shape) { FakeShape.new(body) }
    subject { Player.new(shape) }

    let(:update_position) { subject.validate_position }
  end
end
