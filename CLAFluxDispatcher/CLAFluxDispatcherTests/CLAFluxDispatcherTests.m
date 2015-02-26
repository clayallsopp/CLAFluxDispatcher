//
//  CLAFluxDispatcherTests.m
//  CLAFluxDispatcherTests
//
//  Created by Clay Allsopp on 2/24/15.
//  Copyright (c) 2015 Clay Allsopp. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "CLAFluxDispatcher.h"

@interface CLAFluxDispatcherTests : XCTestCase
@property (nonatomic, strong) CLAFluxDispatcher *dispatcher;
@property (nonatomic, copy) CLAFluxDispatcherCallback callbackA;
@property (nonatomic, copy) CLAFluxDispatcherCallback callbackB;
@property (nonatomic, strong) NSMutableArray *callbackAPayloads;
@property (nonatomic, strong) NSMutableArray *callbackBPayloads;
@end

@implementation CLAFluxDispatcherTests

- (void)setUp {
    [super setUp];

    self.dispatcher = [CLAFluxDispatcher new];

    __weak CLAFluxDispatcherTests *weakSelf = self;
    self.callbackAPayloads = [NSMutableArray new];
    self.callbackA = ^(NSDictionary *payload) {
        [weakSelf.callbackAPayloads addObject:payload];
    };

    self.callbackBPayloads = [NSMutableArray new];
    self.callbackB = ^(NSDictionary *payload) {
        [weakSelf.callbackBPayloads addObject:payload];
    };
}

- (void)tearDown {
    [super tearDown];
}

- (void)testExecutesAllSubscriberCallbacks {
    [self.dispatcher registerCallback:self.callbackA];
    [self.dispatcher registerCallback:self.callbackB];

    NSDictionary *payload = @{};
    [self.dispatcher dispatch:payload];

    XCTAssertEqual(1, self.callbackAPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackAPayloads[0]);
    XCTAssertEqual(1, self.callbackBPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackBPayloads[0]);

    [self.dispatcher dispatch:payload];

    XCTAssertEqual(2, self.callbackAPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackAPayloads[1]);
    XCTAssertEqual(2, self.callbackBPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackBPayloads[1]);
}

- (void)testWaitsForCallbacksRegisteredEarlier {
    id tokenA = [self.dispatcher registerCallback:self.callbackA];

    __weak CLAFluxDispatcherTests *weakSelf = self;
    [self.dispatcher registerCallback:^(NSDictionary *_payload) {
        [weakSelf.dispatcher waitFor:@[tokenA]];
        XCTAssertEqual(1, self.callbackAPayloads.count);
        XCTAssertEqualObjects(_payload, self.callbackAPayloads[0]);
        weakSelf.callbackB(_payload);
    }];

    NSDictionary *payload = @{};
    [self.dispatcher dispatch:payload];

    XCTAssertEqual(1, self.callbackAPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackAPayloads[0]);

    XCTAssertEqual(1, self.callbackBPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackBPayloads[0]);
}

- (void)testWaitsForCallbacksRegisteredLater {
    __block id tokenB = nil;

    __weak CLAFluxDispatcherTests *weakSelf = self;
    [self.dispatcher registerCallback:^(NSDictionary *_payload) {
        [weakSelf.dispatcher waitFor:@[tokenB]];
        XCTAssertEqual(1, self.callbackBPayloads.count);
        XCTAssertEqualObjects(_payload, self.callbackBPayloads[0]);
        weakSelf.callbackA(_payload);
    }];

    tokenB = [self.dispatcher registerCallback:self.callbackB];

    NSDictionary *payload = @{};
    [self.dispatcher dispatch:payload];

    XCTAssertEqual(1, self.callbackAPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackAPayloads[0]);

    XCTAssertEqual(1, self.callbackBPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackBPayloads[0]);
}

- (void)testThrowIfDispatchWhileDispatching {
    __weak CLAFluxDispatcherTests *weakSelf = self;
    [self.dispatcher registerCallback:^(NSDictionary *payload) {
        [weakSelf.dispatcher dispatch:payload];
        weakSelf.callbackA(payload);
    }];

    NSDictionary *payload = @{};
    XCTAssertThrows([self.dispatcher dispatch:payload]);

    XCTAssertEqual(0, self.callbackAPayloads.count);
}

- (void)testThrowIfWaitForWhileNotDispatching {
    id tokenA = [self.dispatcher registerCallback:self.callbackA];

    XCTAssertThrows([self.dispatcher waitFor:@[tokenA]]);

    XCTAssertEqual(0, self.callbackAPayloads.count);
}

- (void)testThrowIfWaitForWithInvalidToken {
    NSString *invalidToken = @"1337";

    __weak CLAFluxDispatcherTests *weakSelf = self;
    [self.dispatcher registerCallback:^(NSDictionary *payload) {
        [weakSelf.dispatcher waitFor:@[invalidToken]];
    }];

    NSDictionary *payload = @{};
    XCTAssertThrows([self.dispatcher dispatch:payload]);
}

- (void)testThrowOnSelfCircularDependencies {
    __weak CLAFluxDispatcherTests *weakSelf = self;
    __block id tokenA = [self.dispatcher registerCallback:^(NSDictionary *payload) {
        [weakSelf.dispatcher waitFor:@[tokenA]];
        weakSelf.callbackA(payload);
    }];

    NSDictionary *payload = @{};
    XCTAssertThrows([self.dispatcher dispatch:payload]);

    XCTAssertEqual(0, self.callbackAPayloads.count);
}

- (void)testThrowOnMultiCircularDependencies {
    __block id tokenA, tokenB = nil;
    __weak CLAFluxDispatcherTests *weakSelf = self;

    tokenA = [self.dispatcher registerCallback:^(NSDictionary *payload) {
        [weakSelf.dispatcher waitFor:@[tokenB]];
        weakSelf.callbackA(payload);
    }];

    tokenB = [self.dispatcher registerCallback:^(NSDictionary *payload) {
        [weakSelf.dispatcher waitFor:@[tokenA]];
        weakSelf.callbackB(payload);
    }];

    NSDictionary *payload = @{};
    XCTAssertThrows([self.dispatcher dispatch:payload]);

    XCTAssertEqual(0, self.callbackAPayloads.count);
    XCTAssertEqual(0, self.callbackBPayloads.count);
}

- (void)testRemainsInConsistentStateAfterFailedDispatch {
    __weak CLAFluxDispatcherTests *weakSelf = self;

    [self.dispatcher registerCallback:self.callbackA];
    [self.dispatcher registerCallback:^(NSDictionary *payload) {
        if ([payload[@"shouldThrow"] boolValue]) {
            [NSException raise:@"Should not happen" format:nil];
        }
        weakSelf.callbackB(payload);
    }];

    NSDictionary *payload = @{@"shouldThrow": @YES};
    XCTAssertThrows([self.dispatcher dispatch:payload]);

    NSInteger callbackACount = self.callbackAPayloads.count;
    NSDictionary *nextPayload = @{@"shouldThrow": @NO};
    [self.dispatcher dispatch:nextPayload];

    XCTAssertEqual(callbackACount + 1, self.callbackAPayloads.count);
    XCTAssertEqual(1, self.callbackBPayloads.count);
}

- (void)testProperlyUnregisterCallbacks {
    [self.dispatcher registerCallback:self.callbackA];

    id tokenB = [self.dispatcher registerCallback:self.callbackB];

    NSDictionary *payload = @{};
    [self.dispatcher dispatch:payload];

    XCTAssertEqual(1, self.callbackAPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackAPayloads[0]);
    XCTAssertEqual(1, self.callbackBPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackBPayloads[0]);

    [self.dispatcher unregisterCallback:tokenB];

    [self.dispatcher dispatch:payload];
    XCTAssertEqual(2, self.callbackAPayloads.count);
    XCTAssertEqualObjects(payload, self.callbackAPayloads[1]);
    XCTAssertEqual(1, self.callbackBPayloads.count);
}

@end
