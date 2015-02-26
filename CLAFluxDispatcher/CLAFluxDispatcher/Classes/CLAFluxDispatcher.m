//
//  CLAFluxDispatcher.m
//  CLAFluxDispatcher
//
//  Created by Clay Allsopp on 2/24/15.
//  Copyright (c) 2015 Clay Allsopp. All rights reserved.
//

#import "CLAFluxDispatcher.h"

static const NSString *_prefix = @"ID_";
static int _lastId = 1;

static void invariant(BOOL condition, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    if (!condition) {
        [NSException raise:@"CLAFluxDispatcherInvariantViolation" format:format arguments:args];
    }
    va_end(args);
}

static BOOL isTrue(NSNumber *value) {
    return value && [value boolValue];
}


@interface CLAFluxDispatcher ()
@property (nonatomic, strong) NSMutableDictionary *callbacks;
@property (nonatomic, strong) NSMutableDictionary *isPending;
@property (nonatomic, strong) NSMutableDictionary *isHandled;
@property (nonatomic, readwrite) BOOL isDispatching;
@property (nonatomic, strong) NSDictionary *pendingPayload;

- (void)invokeCallback:(NSString *)dispatchToken;
- (void)startDispatching:(NSDictionary *)payload;
@end

@implementation CLAFluxDispatcher

- (instancetype) init {
    if (self = [super init]) {
        self.callbacks = [NSMutableDictionary new];
        self.isPending = [NSMutableDictionary new];
        self.isHandled = [NSMutableDictionary new];
        self.isDispatching = NO;
        self.pendingPayload = nil;
    }

    return self;
}

- (id)registerCallback:(CLAFluxDispatcherCallback)callback {
    NSString *token = [NSString stringWithFormat:@"%@%i", _prefix, _lastId];
    _lastId = _lastId + 1;
    self.callbacks[token] = [callback copy];
    return token;
}

- (void)unregisterCallback:(id)dispatchToken {
    invariant(
        !![self.callbacks objectForKey:dispatchToken],
        @"CLAFluxDispatcher.unregisterCallback(...): '%@' does map to a registered callback",
        dispatchToken
    );
    [self.callbacks removeObjectForKey:dispatchToken];
}

- (void)waitFor:(NSArray *)dispatchTokens {
    invariant(
        self.isDispatching,
        @"Dispatcher.waitFor(...): Must be invoked while dispatching."
    );
    for (NSString *dispatchToken in dispatchTokens) {
        if (isTrue(self.isPending[dispatchToken])) {
            invariant(isTrue(self.isHandled[dispatchToken]),
                @"CLAFluxDispatcher.waitFor(...): Circular dependency detected while waiting for %@",
                dispatchToken
            );
            continue;
        }
        invariant(
            !![self.callbacks objectForKey:dispatchToken],
            @"CLAFluxDispatcher.unregisterCallback(...): '%@' does map to a registered callback",
            dispatchToken
        );
        [self invokeCallback: dispatchToken];
    }
}

- (void)dispatch:(NSDictionary *)payload {
    invariant(
        !self.isDispatching,
        @"CLAFluxDispatcher.dispatch(...): Cannot dispatch in the middle of a dispatch"
    );
    [self startDispatching: payload];
    @try {
        for (NSString *dispatchToken in [self.callbacks allKeys]) {
            if (isTrue(self.isPending[dispatchToken])) {
                continue;
            }
            [self invokeCallback:dispatchToken];
        }
    }
    @finally {
        [self stopDispatching];
    }
}

- (void)invokeCallback:(NSString *)dispatchToken {
    self.isPending[dispatchToken] = @YES;
    CLAFluxDispatcherCallback callback = self.callbacks[dispatchToken];
    callback(self.pendingPayload);
    self.isHandled[dispatchToken] = @YES;
}

- (BOOL)isDispatching {
    return _isDispatching;
}

- (void)startDispatching:(NSDictionary *)payload {
    for (NSString *dispatchToken in [self.callbacks allKeys]) {
        self.isPending[dispatchToken] = @NO;
        self.isHandled[dispatchToken] = @NO;
    }
    self.pendingPayload = payload;
    self.isDispatching = YES;
}

- (void)stopDispatching {
    self.pendingPayload = nil;
    self.isDispatching = NO;
}

@end
