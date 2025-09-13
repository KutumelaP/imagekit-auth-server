<?php
$UPSTREAM='https://us-central1-marketplace-8d6bd.cloudfunctions.net/payfastNotify';
proxy($UPSTREAM);
function proxy($url){
  $method=$_SERVER['REQUEST_METHOD'] ?? 'GET';
  $qs=$_SERVER['QUERY_STRING'] ?? '';
  $headers=function_exists('getallheaders')? getallheaders():[];
  $opts=['http'=>['method'=>$method,'header'=>buildHeaders($headers),'ignore_errors'=>true]];
  if($method==='POST'){
    $opts['http']['content']=file_get_contents('php://input');
  }
  $context=stream_context_create($opts);
  $resp=@file_get_contents($url.($qs?('?'.$qs):''),false,$context);
  $statusLine=$http_response_header[0] ?? 'HTTP/1.1 200 OK';
  if(preg_match('/\s(\d{3})\s/',$statusLine,$m)){
    http_response_code(intval($m[1]));
  }
  foreach(($http_response_header??[]) as $h){
    if(stripos($h,'content-type:')===0 || stripos($h,'location:')===0){ header($h); }
  }
  echo $resp;
}
function buildHeaders($headers){
  $out='';
  foreach($headers as $k=>$v){
    $kk=strtolower($k);
    if($kk==='host' || $kk==='content-length') continue;
    $out.="$k: $v\r\n";
  }
  return $out;
}


