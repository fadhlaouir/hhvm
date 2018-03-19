<?hh

function x($x, $y, $a = array(1,2,3), $b = vec[]) {
  return $x + $y;
}

class F {
  function x($x, $y, $a = array(1,2,3), $b = vec[]) {
    return $x + $y;
  }
}

var_dump(
  array_map(
    $x ==> $x->isOptional() ? $x->getDefaultValueText() : '',
    (new ReflectionFunction('x'))->getParameters()
  )
);

var_dump(
  array_map(
    $x ==> $x->isOptional() ? $x->getDefaultValueText() : '',
    (new ReflectionMethod('F', 'x'))->getParameters()
  )
);
