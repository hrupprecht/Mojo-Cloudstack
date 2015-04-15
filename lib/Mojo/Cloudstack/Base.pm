package Mojo::Cloudstack::Base;
use Mojo::Base -base;
use Mojo::Util 'monkey_patch';

sub new {
  my $class = shift;
  my $cs_class = shift;
  my $self = bless shift, $cs_class;

  no strict 'refs';
  no warnings 'redefine';
  foreach my $key (keys %$self){
    *{"${cs_class}::${key}"} = sub {
      my ($self, $value) = @_;
      return $value ? (($self->{$key} = $value) and $self) : $self->{$key};
    }
  }
  return $self;
}

1;
