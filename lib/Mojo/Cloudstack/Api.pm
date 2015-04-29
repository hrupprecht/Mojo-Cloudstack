package Mojo::Cloudstack::Api;
use Mojo::Base 'Mojo::Cloudstack::Base';

has '_cs';

sub __build_module_class {
  my ($self) = @_;
  my $name = $self->name;
  my $desc = $self->description;
  my $response = $self->response;
  my $isasync = $self->isasync;
  my $class = ucfirst($self->name);
  my $attrs = join("\n", map {"has '" . $_->{name} . "'"} @{$self->params});
  my $params =join("\n    ", map {$_->{name} . " => \$self->" . $_->{name} . " // '',"} @{$self->params});
  return <<EOT;
package Mojo::Cloudstack::$class;

has description => '$desc';
has isasync => sub { $isasync };
$attrs

sub exec {
  my \$self = shift;
  return \$self->_cs->$name(
    $params
  );
}

1;

EOT

}

1;
