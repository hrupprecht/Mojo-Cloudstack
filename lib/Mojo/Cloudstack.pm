package Mojo::Cloudstack;

use Mojo::Base 'Mojo::UserAgent';
use Mojo::Parameters;
use Mojo::URL;
use Mojo::UserAgent;
use Mojo::JSON 'j';
use Mojo::Collection 'c';
use Mojo::Cloudstack::Base;
use Mojo::Cloudstack::Api;
use Digest::HMAC_SHA1 qw(hmac_sha1 hmac_sha1_hex);
use MIME::Base64;
use URI::Encode 'uri_encode';
use Data::Dumper 'Dumper';

has 'host'        => "localhost";
has 'path'        => "/client/api";
has 'port'        => "8080";
has 'scheme'      => "https";
has 'api_key'     => "";
has 'secret_key'  => "";

our $VERSION = '0.01';
our $AUTOLOAD;

sub _build_request {
  my ($self, $params) = @_;
  my $baseurl = sprintf ("%s://%s:%s%s?", $self->scheme, $self->host, $self->port, $self->path);
  $params->{ apiKey }   = $self->api_key;
  $params->{ response } = 'json';
  my $secret_key = $self->secret_key;

  my $req_params = Mojo::Parameters->new();
  foreach my $p (sort keys %$params) {
    $req_params->param($p => uri_encode($params->{ $p }));
  }
  my $params_str = lc ($req_params->to_string);
  my $digest = hmac_sha1($params_str, $secret_key);
  my $base64_encoded = encode_base64($digest);
  chomp ($base64_encoded);

  my $uri_encoded = uri_encode($base64_encoded,1);
  my $url = Mojo::URL->new($baseurl);
  $url->query($req_params->to_string);

  return $url->to_string . '&signature='.$uri_encoded;

}

sub __build_modules {
  my ($self, @args) = @_;
  my $apis = $self->listApis;
  $apis->each(sub {
    my ($e, $num) = @_;
    say Dumper $num, $e;
    #say Dumper $e->response;
    say Dumper $e->__build_module_class;
  });

}

sub AUTOLOAD {
  my $self = shift;
  (my $command = $AUTOLOAD) =~ s/.*:://;
  my %params = @_;
  $params{command} = $command;
  my $req = $self->_build_request(\%params);
  my $res = $self->get($req)->res;
  my $items = $res->json;
  #warn Dumper 'ITEMS', $items;
  die sprintf("Could not get response for %s %s %s", $req,  $res->code, $res->message) unless $items;
  my $responsetype = (keys %$items)[0];

  $items->{$responsetype}{_cs} = $self;
  if($responsetype =~ /^(list|expunge|error|create|update|delete|stop|start|restart|deploy|assign|attach|detach|query)(.*)(response)$/){
    my ($otype, $oname, $oresponse) = ($1, $2, $3);
    #warn Dumper $otype, $oname, $oresponse;
    if($oname =~ /(s)$/){
      $oname =~ s/$1$//;
    }
    if($otype eq 'list'){
      return c(
        map {
          $_->{_cs} = $self;
          Mojo::Cloudstack::Base->new('Mojo::Cloudstack::' . ucfirst($oname),$_);
        } @{$items->{$responsetype}{$oname}}
      );
    } elsif($otype eq 'query'){
      #warn Dumper 'QUERY', $responsetype, $items->{$responsetype};
      return  Mojo::Cloudstack::Base->new('Mojo::Cloudstack::AsyncJobResult', $items->{$responsetype});

    } elsif(exists $items->{$responsetype}{errorcode}){
      return  Mojo::Cloudstack::Base->new('Mojo::Cloudstack::Error', $items->{$responsetype});
    } else {
      return  Mojo::Cloudstack::Base->new('Mojo::Cloudstack::' . (exists $items->{$responsetype}{jobid}
        ? 'AsyncJobRequest'
        : ucfirst($oname)), $items->{$responsetype});
    }
  } else {
    die "unknown response type $responsetype for reqest \n$req";
  }

}

1;

__END__

=pod

=head1 NAME

Mojo::Cloudstack

=head1 DESCRIPTION

Generic Class for Cloudstack API call


=head1 SYNOPSIS

  use Mojo::Cloudstack;

=head1 METHODS

=head2 new

  my $cs = Mojo::Cloudstack->new(
    host       => "cloustack.local",
    path       => "/client/api",
    port       => "443",
    scheme     => "https",
    api_key    => $api_key,
    secret_key => $secret_key,
  );

  my $vmreq = $cs->deployVirtualMachine(
    serviceofferingid => $so->id,
    templateid => $t->id,
    zoneid => $zone1->id,
    projectid => $project_id,
  );

=head2 _build_request

  my $params = Mojo::Parameters->new('command=listUsers&response=json');
  $params->append(apiKey => $cs->api_key);
  my $req = $cs->_build_request($params->to_hash)

=head2 api_key

API Key from Cloudstack

=head2  host

Host to connect to

=head2 path

URL path to API

=head2 port

Port to connect to

=head2 scheme

URL scheme http | https

=head2 secret_key

Secret Key from Cloudstack

=cut
