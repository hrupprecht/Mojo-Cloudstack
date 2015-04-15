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
    };
    if($key eq 'jobresult'){
      my $otype = (keys %{$self->{jobresult}})[0];
      $self->$key(
        Mojo::Cloudstack::Base->new('Mojo::Cloudstack::' . ucfirst($otype), $self->{$key}{$otype})
      );
    }
  }
  return $self;
}

1;
