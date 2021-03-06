package Rewire;

use 5.014;

use strict;
use warnings;

use registry;
use routines;

use Data::Object::Class;
use Data::Object::ClassHas;
use Data::Object::Space;

use Carp;
use JSON::Validator;
use Rewire::Engine;

with 'Data::Object::Role::Buildable';
with 'Data::Object::Role::Proxyable';

# VERSION

# BUILD

fun build_self($self, $args) {

  # build context and eager load services
  return $self->context;
}

fun build_proxy($self, $package, $method, @args) {
  return unless $self->config->{services}{$method};

  return sub {

    return $self->process($method, @args);
  }
}

# ATTRIBUTES

has 'context' => (
  is => 'ro',
  isa => 'CodeRef',
  new => 1
);

fun new_context($self) {
  $self->engine->call('preload', $self->config);
}

has 'engine' => (
  is => 'ro',
  isa => 'InstanceOf["Data::Object::Space"]',
  new => 1
);

fun new_engine($self) {
  Data::Object::Space->new('Rewire::Engine');
}

has 'metadata' => (
  is => 'ro',
  isa => 'HashRef',
  opt => 1
);

has 'services' => (
  is => 'ro',
  isa => 'HashRef',
  opt => 1
);

# METHODS

method config() {
  {
    metadata => $self->metadata || {},
    services => $self->services || {},
  }
}

method resolve(Str $name) {
  my $engine = $self->engine;

  my $result = $engine->call('reifier', $name, $self->config, $self->context);

  return $result;
}

method process(Str $name, Any $argument, Maybe[Str] $argument_as) {
  my $engine = $self->engine;
  my $service = $self->services->{$name} or return;

  my $generated = {
    %$service, $argument_as ? (argument_as => $argument_as) : ()
  };

 $argument //= $service->{argument};

  my $params = $engine->call('resolver', $argument, $self->config, $self->context);
  my $result = $engine->call( 'builder', $generated, $params // $service->{argument});

  return $result;
}

method validate() {
  my $engine = $self->engine;

  my $json = JSON::Validator->new;

  $json->schema($engine->call('ruleset'));

  my @errors = map "$_", $json->validate($self->config);

  confess join "\n", @errors if @errors;

  return $self;
}

1;
