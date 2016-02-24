# Encoding: UTF-8

# Ruby Hack Night Asteroids by David Andrews and Jason Schweier, 2016

require_relative 'asteroid/large'
require_relative 'player'
require_relative 'level'
require_relative 'alien'
require_relative 'dock'
require_relative 'score'
require_relative 'zorder'

# The Gosu::Window is always the "environment" of our game
# It also provides the pulse of our game
class Game < Gosu::Window

  # Time increment over which to apply a physics "step" ("delta t")
  @@dt = 1.0/60.0

  def initialize
    super WIDTH, HEIGHT

    self.caption = "Ruby Hack Night Asteroids"

    # Create our Space
    @space = CP::Space.new

    # Our space contains four types of things
    @asteroids = Array.new
    @shots = Array.new # this includes both player's and alien's
    @player = Player.new(@shots, @@dt)
    @alien = Alien.new(@shots)

    # Game progress indicators
    @level = Level.new(@space, @asteroids)
    @score = Score.new
    @dock = Dock.new(3) # this is our display of ships below the score

    # COLLISIONS
    # Here we define what is supposed to happen when things collide
    # Also note that both shapes involved in the collision are passed into the closure
    # in the same order that their collision_types are defined in the add_collision_func call
    @split_asteroids = []
    @dead_shots = []

    @space.add_collision_func(:shot, :asteroid) do |shot_shape, asteroid_shape|
      @dead_shots << shot_shape.object
      @split_asteroids << asteroid_shape.object
    end

    @space.add_collision_func(:shot, :ship) do |shot_shape, ship_shape|
      next if ship_shape.object.invulnerable?
      @dead_shots << shot_shape.object
      @player.destroyed!
    end

    @space.add_collision_func(:shot, :alien) do |shot_shape, alien_shape|
      @dead_shots << shot_shape.object
      @alien.destroyed!
    end

    @space.add_collision_func(:ship, :asteroid) do |ship_shape, asteroid_shape|
      next if ship_shape.object.invulnerable?
      @player.destroyed!
      @split_asteroids << asteroid_shape.object
    end

    @space.add_collision_func(:ship, :alien) do |ship_shape, alien_shape|
      next if ship_shape.object.invulnerable?
      @player.destroyed!
      @alien.destroyed!
    end

    # Here we tell Space that we don't want one asteroid bumping into another
    # The reason we need to do this is because when the Player hits a asteroid,
    # the asteroid will travel until it is removed in the update cycle below
    # which means it may collide and therefore push other asteroids
    # To see the effect, remove this line and play the game, every once in a while
    # you'll see an asteroid moving
    @space.add_collision_func(:asteroid, :asteroid, &nil)
    @space.add_collision_func(:shot, :shot, &nil)
    @space.add_collision_func(:ship, :ship, &nil) # for two player? ;)

    # SOUNDS
    @high_doop = Gosu::Sample.new("media/high.wav")
    @low_doop = Gosu::Sample.new("media/low.wav")
    @free_ship_sound = Gosu::Sample.new("media/freeship.wav")

    # Ready...set...play!
    @player.add_to_space(@space)
  end

  def update
    # Step 
    # Perform the step over @dt period of time
    # For best performance @dt should remain consistent for the game
    @space.step(@@dt)

    # Shots
    # Some shots die due to collisions (see collision code), some die of old age
    @dead_shots += @shots.select { |s| s.old? }
    @dead_shots.each do |shot|
      @shots.delete(shot)
      shot.remove_from_space(@space)
    end
    @dead_shots.clear

    @shots.each(&:validate_position)

    # Player
    if @player.destroyed
      @dock.use_ship
      @player.accelerate_none
      @player.new_ship unless @dock.empty?
    else
      # When a force or torque is set on a body, it is cumulative
      # This means that the force you applied last SUBSTEP will compound with the
      # force applied this SUBSTEP; which is probably not the behavior you want
      # We reset the forces on the Player each SUBSTEP for this reason
      @player.reset_forces

      # Acceleration/deceleration
      @player.apply_damping
      accelerate_control_pressed ? @player.accelerate : @player.accelerate_none

      # Turning
      @player.turn_none
      @player.turn_right if turn_right_control_pressed
      @player.turn_left if turn_left_control_pressed

      shoot_control_pressed ? @player.shoot(@space) : @player.shoot_none

      hyperspace_control_pressed ? @player.hyperspace : @player.hyperspace_none
      @player.validate_position
    end

    # Asteroids
    @split_asteroids.each do |asteroid|
      @asteroids.delete(asteroid)
      @asteroids.concat(asteroid.split(@space))
      @score.increment(asteroid.points)
      if @score.reward_free_ship
        @dock.reward_ship
        @free_ship_sound.play
      end
    end
    @split_asteroids.clear

    @asteroids.each(&:validate_position)

    conditionally_play_doop

    # See if we need to add more asteroids...
    @level.next! if @level.complete?
  end

  def draw
    if @dock.empty?
      draw_game_over
    else
      @player.draw
    end
    @asteroids.each(&:draw)
    @shots.each(&:draw)
    @score.draw_at(180, 0)
    @dock.draw_at(100, 70)
  end

  def button_down(id)
    close if id == Gosu::KbEscape
  end

private
  def conditionally_play_doop
    @last_doop_time ||= Gosu.milliseconds
    doop_delay = @asteroids.inject(1) { |s,a| s + a.scale } * 80
    if @last_doop_time + doop_delay < Gosu.milliseconds
      @doop_sound = (@doop_sound == @high_doop) ? @low_doop : @high_doop
      @doop_sound.play
      @last_doop_time = Gosu.milliseconds
    end
  end

  def draw_game_over
    font = Gosu::Font.new(70, name: "media/Hyperspace.ttf")
    middle = 0.5
    center = 0.5
    font.draw_rel("GAME OVER", WIDTH/2, HEIGHT/2, ZOrder::UI, middle, center)
  end

  def accelerate_control_pressed
    Gosu::button_down?(Gosu::KbUp)
  end
  def turn_right_control_pressed
    Gosu::button_down?(Gosu::KbRight) && !Gosu::button_down?(Gosu::KbLeft)
  end
  def turn_left_control_pressed
    Gosu::button_down?(Gosu::KbLeft) && !Gosu::button_down?(Gosu::KbRight)
  end
  def shoot_control_pressed
    Gosu::button_down?(Gosu::KbSpace)
  end
  def hyperspace_control_pressed
    Gosu::button_down?(Gosu::KbLeftShift) || Gosu::button_down?(Gosu::KbRightShift)
  end
end
