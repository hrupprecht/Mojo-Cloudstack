package Mojo::Cloudstack;

use Mojo::Base -base;
use Mojo::Util 'slurp';
use Digest::HMAC_SHA1 qw(hmac_sha1 hmac_sha1_hex);
use MIME::Base64;
use URI::Encode 'uri_encode';

has 'host'        => "localhost";
has 'path'        => "/client/api";
has 'port'        => "8080";
has 'scheme'      => "https";
has 'api_key'     => "";
has 'secret_key'  => "";

our $VERSION = '0.01';

sub api_key {
  my ($self, $key) = @_;
  return $self->_api_key unless $key;
  $self->_api_key($key);
}

sub secret_key
{
  my ($self, $key) = @_;
  return $self->_secret_key unless $key;
  ($key = slurp($key)) =~ s/\n$//;
  $self->_secret_key($key);
}

sub _build_request
{
  my ($self, $params, $response) = @_;
  $response //=  'json';
  my $baseurl = sprintf ("%s://%s:%s%s?", $self->scheme, $self->host, $self->port, $self->path);
  $params->{ apiKey }   = $self->api_key;
  $params->{ response } = $response;
  my $secret_key = $self->secret_key;

  my $req_params = Mojo::Parameters->new();
  foreach my $p (sort keys %$params) {
    $req_params->param($p => $params->{ $p });
  }
  my $params_str = lc ($req_params->to_string);


  my $digest = hmac_sha1($params_str, $secret_key);
  my $base64_encoded = encode_base64($digest);
  chomp ($base64_encoded);
  my $url_encoded = uri_encode($base64_encoded, 1);    # encode_reserved option is set to 1


  $req_params->append(signature => $url_encoded);

  my $url = Mojo::URL->new($baseurl);
  $url->query($req_params->to_string);

  return $url->to_string;

}

1;
