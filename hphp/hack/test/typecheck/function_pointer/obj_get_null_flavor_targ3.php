<?hh

final class Foo {
  public ?Foo $foo = null;

  public function bar<T>(T $x): T {
    return $x;
  }
}

function baz(?Foo $x): void {
  $y = $x?->foo?->bar<>;
  if (!($y is null)) {
    $y(4);
  }
}
