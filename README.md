# CLAFluxDispatcher

A port of Facebook's [Flux Dispatcher](https://github.com/facebook/flux) to Objective-C

## Installation

Via [CocoaPods](http://cocoapods.org):

```
pod 'CLAFluxDispatcher'
```

Adding the files into your source tree will also work, there are no dependencies.

## Usage

This is adapted from the [Flux documentation](https://github.com/facebook/flux/blob/f21c43e2864c62c8043df3d48b4540d3705c3d00/src/Dispatcher.js#L21)

`CLAFluxDispatcher` is used to broadcast payloads to registered callbacks. This is different from generic pub-sub systems in two ways:

1. Callbacks are not subscribed to particular events. Every payload is dispatched to every registered callback.
2. Callbacks can be deferred in whole or part until other callbacks have been executed.

For example, consider this hypothetical flight destination form, which selects a default city when a country is selected:

```objc
CLAFluxDispatcher *flightDispatcher = [CLAFluxDispatcher new];

// Keeps track of which country is selected
NSMutableDictionary *countryStore = @{@"country": [NSNull null]};

// Keeps track of which city is selected
NSMutableDictionary *cityStore = @{@"city": [NSNull null]};

// Keeps track of the base flight price of the selected city
NSMutableDictionary *flightPriceStore = @{@"price": [NSNull null]};
```

When a user changes the selected city, we dispatch the payload:

```objc
[flightDispatcher dispatch:@{
  @"actionType": @"city-update",
  @"selectedCity": @"paris"
}];
```

This payload is digested by `cityStore`:

```objc
[flightDispatcher registerCallback:^(NSDictionary *payload) {
  if ([payload[@"actionType"] isEqualToString:@"city-update"]) {
    cityStore[@"city"] = payload[@"selectedCity"];
  }
}]
```

When the user selects a country, we dispatch the payload:

```objc
[flightDispatcher dispatch:@{
  @"actionType": @"country-update",
  @"selectedCountry": @"australia"
}];
```

This payload is digested by both stores:

```objc
countryStore[@"dispatchToken"] = [flightDispatcher registerCallback:^(NSDictionary *payload) {
  if ([payload[@"actionType"] isEqualToString:@"country-update"]) {
    countryStore[@"country"] = payload[@"selectedCountry"];
  }
}];
```

When the callback to update `countryStore` is registered, we save a reference to the returned token. Using this token with `waitFor()`, we can guarantee that `countryStore` is updated before the callback that updates `cityStore` needs to query its data.

```objc
cityStore[@"dispatchToken"] = [flightDispatcher registerCallback:^(NSDictionary *payload) {
  if ([payload[@"actionType"] isEqualToString:@"country-update"]) {
    // `countryStore[@"country"]` may not be updated.
    [flightDispatcher waitFor:@[countryStore[@"dispatchToken"]]];
    // `countryStore[@"country"]` is now guaranteed to be updated.

    // Select the default city for the new country
    cityStore[@"city"] = getDefaultCityForCountry(countryStore[@"country"]);
  }
}];
```

The usage of `waitFor()` can be chained, for example:

```objc
flightPriceStore[@"dispatchToken"] =
  [flightDispatcher registerCallback:^(NSDictionary *payload) {
    if ([payload[@"actionType"] isEqualToString: @"country-update"]) {
      [flightDispatcher waitFor: @[cityStore[@"dispatchToken"]]];
      flightPriceStore[@"price"] =
        getFlightPriceStore(countryStore[@"country"], cityStore[@"city"]);
    }
    else if ([payload[@"actionType"] isEqualToString: @"city-update"]) {
      flightPriceStore[@"price"] =
        getFlightPriceStore(countryStore[@"country"], cityStore[@"city"]);
    }
  }];
```

The `country-update` payload will be guaranteed to invoke the stores' registered callbacks in order: `countryStore`, `cityStore`, then `flightPriceStore`.