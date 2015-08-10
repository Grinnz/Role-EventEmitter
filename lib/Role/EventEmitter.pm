package Role::EventEmitter;

use Scalar::Util qw(blessed weaken);
use constant DEBUG => $ENV{ROLE_EVENTEMITTER_DEBUG} || 0;

use Moo::Role;

our $VERSION = '0.001';

has '_events' => (
  is => 'ro',
  lazy => 1,
  default => sub { {} },
  init_arg => undef,
);

sub catch { $_[0]->on(error => $_[1]) and return $_[0] }

sub emit {
  my ($self, $name) = (shift, shift);

  if (my $s = $self->_events->{$name}) {
    warn "-- Emit $name in @{[blessed $self]} (@{[scalar @$s]})\n" if DEBUG;
    for my $cb (@$s) { $self->$cb(@_) }
  }
  else {
    warn "-- Emit $name in @{[blessed $self]} (0)\n" if DEBUG;
    die "@{[blessed $self]}: $_[0]" if $name eq 'error';
  }

  return $self;
}

sub has_subscribers { !!shift->_events->{shift()} }

sub on { push @{$_[0]->_events->{$_[1]}}, $_[2] and return $_[2] }

sub once {
  my ($self, $name, $cb) = @_;

  weaken $self;
  my $wrapper;
  $wrapper = sub {
    $self->unsubscribe($name => $wrapper);
    $cb->(@_);
  };
  $self->on($name => $wrapper);
  weaken $wrapper;

  return $wrapper;
}

sub subscribers { shift->_events->{shift()} ||= [] }

sub unsubscribe {
  my ($self, $name, $cb) = @_;

  # One
  if ($cb) {
    $self->_events->{$name} = [grep { $cb ne $_ } @{$self->_events->{$name}}];
    delete $self->_events->{$name} unless @{$self->_events->{$name}};
  }

  # All
  else { delete $self->_events->{$name} }

  return $self;
}

1;

=head1 NAME

Role::EventEmitter - Event emitter role for Moo(se) classes

=head1 SYNOPSIS

  package Cat;
  use Moo;
  with 'Role::EventEmitter';

  # Emit events
  sub poke {
    my $self = shift;
    $self->emit(roar => 3);
  }

  package main;

  # Subscribe to events
  my $tiger = Cat->new;
  $tiger->on(roar => sub {
    my ($tiger, $times) = @_;
    say 'RAWR!' for 1 .. $times;
  });
  $tiger->poke;

=head1 DESCRIPTION

L<Role::EventEmitter> is a simple L<Moo::Role> for event emitting objects based
on L<Mojo::EventEmitter>.

=head1 EVENTS

L<Role::EventEmitter> can emit the following events.

=head2 error

  $e->on(error => sub {
    my ($e, $err) = @_;
    ...
  });

This is a special event for errors, it will not be emitted directly by the
class consuming this role but is fatal if unhandled.

  $e->on(error => sub {
    my ($e, $err) = @_;
    say "This looks bad: $err";
  });

=head1 METHODS

L<Role::EventEmitter> composes the following methods.

=head2 catch

  $e = $e->catch(sub {...});

Subscribe to L</"error"> event.

  # Longer version
  $e->on(error => sub {...});

=head2 emit

  $e = $e->emit('foo');
  $e = $e->emit('foo', 123);

Emit event.

=head2 has_subscribers

  my $bool = $e->has_subscribers('foo');

Check if event has subscribers.

=head2 on

  my $cb = $e->on(foo => sub {...});

Subscribe to event.

  $e->on(foo => sub {
    my ($e, @args) = @_;
    ...
  });

=head2 once

  my $cb = $e->once(foo => sub {...});

Subscribe to event and unsubscribe again after it has been emitted once.

  $e->once(foo => sub {
    my ($e, @args) = @_;
    ...
  });

=head2 subscribers

  my $subscribers = $e->subscribers('foo');

All subscribers for event.

  # Unsubscribe last subscriber
  $e->unsubscribe(foo => $e->subscribers('foo')->[-1]);

  # Change order of subscribers
  @{$e->subscribers('foo')} = reverse @{$e->subscribers('foo')};

=head2 unsubscribe

  $e = $e->unsubscribe('foo');
  $e = $e->unsubscribe(foo => $cb);

Unsubscribe from event.

=head1 DEBUGGING

You can set the C<ROLE_EVENTEMITTER_DEBUG> environment variable to get some
advanced diagnostics information printed to C<STDERR>.

  ROLE_EVENTEMITTER_DEBUG=1

=head1 BUGS

Report any issues on the public bugtracker.

=head1 AUTHOR

Dan Book <dbook@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2015 by Dan Book.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=head1 SEE ALSO

L<Mojo::EventEmitter>, L<Mixin::Event::Dispatch>
