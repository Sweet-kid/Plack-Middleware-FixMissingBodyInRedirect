use strict;
use warnings;

package Plack::Middleware::FixMissingBodyInRedirect::Proxy;

sub new {
  my ($class, $target, $default_body) = @_;
  my %attrs = (
    _t => $target, 
    _first_call => 1, 
    _db => $default_body
  );
  return bless \%attrs, $class;
}

sub getline {
  my $self = shift;
  my $line = $self->{_t}->getline;
  if($self->{_first_call} && !defined($line)) {
    $self->{_first_call} = 0;
    $line = $self->{_db};
  }
  return $line;
}

sub AUTOLOAD {
  my ($self, @args) = @_;
  my ($method) = (our $AUTOLOAD =~ /([^:]+)$/);
  return $self->{_t}->$method(@args)
}

1;


