package My::EventEmitter;
use Role::Tiny::With;
with 'Role::EventEmitter';

sub new { bless {}, shift }

package main;
use strict;
use warnings;
use Test::More;
use Test::Needs 'Mojo::IOLoop', 'Mojo::Promise';

sub _tick { my $t = Mojo::IOLoop->timer(0.1 => sub {}); Mojo::IOLoop->one_tick; Mojo::IOLoop->remove($t) }

my $e = My::EventEmitter->new;

# One-time event
my $once;
my $p = $e->once_p('one_time')->then(sub { $once++ });
is scalar @{$e->subscribers('one_time')}, 1, 'one subscriber';
$e->unsubscribe(one_time => sub { });
is scalar @{$e->subscribers('one_time')}, 1, 'one subscriber';
$e->emit('one_time');
_tick;
is $once, 1, 'event was emitted once';
is scalar @{$e->subscribers('one_time')}, 0, 'no subscribers';
$e->emit('one_time');
_tick;
is $once, 1, 'event was not emitted again';
$e->emit('one_time');
_tick;
is $once, 1, 'event was not emitted again';
$e->emit('one_time');
_tick;
is $once, 1, 'event was not emitted again';
my $p2;
$p = $e->once_p('one_time')->then(sub {
  $p2 = shift->once_p('one_time')->then(sub { $once++ }); 1
});
$e->emit('one_time');
_tick;
is $once, 1, 'event was emitted once';
$e->emit('one_time');
_tick;
is $once, 2, 'event was emitted again';
$e->emit('one_time');
_tick;
is $once, 2, 'event was not emitted again';
$p = $e->once_p('one_time')->then(sub { $once = shift->has_subscribers('one_time') });
$e->emit('one_time');
_tick;
ok !$once, 'no subscribers';

# Nested one-time events
$once = 0;
my $p3;
$p = $e->once_p('one_time')
  ->then(sub {
    $p2 = shift->once_p('one_time')
      ->then(sub {
        $p3 = shift->once_p('one_time')->then(sub { $once++ }); 1
      }
    ); 1
  }
);
is scalar @{$e->subscribers('one_time')}, 1, 'one subscriber';
$e->emit('one_time');
_tick;
is $once, 0, 'only first event was emitted';
is scalar @{$e->subscribers('one_time')}, 1, 'one subscriber';
$e->emit('one_time');
_tick;
is $once, 0, 'only second event was emitted';
is scalar @{$e->subscribers('one_time')}, 1, 'one subscriber';
$e->emit('one_time');
_tick;
is $once, 1, 'third event was emitted';
is scalar @{$e->subscribers('one_time')}, 0, 'no subscribers';
$e->emit('one_time');
_tick;
is $once, 1, 'event was not emitted again';
$e->emit('one_time');
_tick;
is $once, 1, 'event was not emitted again';
$e->emit('one_time');
_tick;
is $once, 1, 'event was not emitted again';

# One-time event used directly
$e = My::EventEmitter->new;
ok !$e->has_subscribers('foo'), 'no subscribers';
$once = 0;
$p = $e->once_p('foo');
$p->then(sub { $once++ });
ok $e->has_subscribers('foo'), 'has subscribers';
$p->resolve;
_tick;
is $once, 1, 'event was emitted once';
ok !$e->has_subscribers('foo'), 'no subscribers';

# Unsubscribe
$e = My::EventEmitter->new;
my $counter;
$p = $e->once_p('foo');
$p->then(sub { $counter++ });
$p->reject;
_tick;
is scalar @{$e->subscribers('foo')}, 0, 'no subscribers';
$e->emit('foo');
_tick;
is $counter, undef, 'event was not emitted';

# Unsubscribe all
$e = My::EventEmitter->new;
$p = $e->once_p('foo')->then(sub { $counter++ });
$e->unsubscribe('foo');
is scalar @{$e->subscribers('foo')}, 0, 'no subscribers';
$e->emit('foo');
_tick;
is $counter, undef, 'event was not emitted';

done_testing();
