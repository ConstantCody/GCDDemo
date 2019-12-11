//
//  ViewController.m
//  GCDDemo
//
//  Created by Constant Cody on 11/10/19.
//  Copyright © 2019 jbangit. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic) dispatch_semaphore_t ticketSemaphore;
@property (nonatomic) NSInteger ticketCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self syncConcurrent];
    
//    [self apply];
//    [self groupNotify];
//    [self groupWait];
//    [self groupEnterAndLeave];
//    [self semaphoreSync];
//    [self semaphoreSafe];
}

// MARK: 简单使用

/// 同步+并发
- (void)syncConcurrent {
    NSLog(@"同步+并发start, %@", [NSThread currentThread]);
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 模拟耗时操作
        sleep(2);
        NSLog(@"同步+并发ing, %@", [NSThread currentThread]);
    });
    NSLog(@"同步+并发end, %@", [NSThread currentThread]);
}

// MARK: 高级用法

/// 快速迭代方法：dispatch_apply
- (void)apply {
    NSLog(@"任务start, %@", [NSThread currentThread]);
    dispatch_apply(10, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t index) {
        NSLog(@"任务%zd，%@", index, [NSThread currentThread]);
    });
    NSLog(@"任务end, %@", [NSThread currentThread]);
}

/// dispatch_group_notify
- (void)groupNotify {
    NSLog(@"任务start, %@", [NSThread currentThread]);
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 【异步线程 + 并发队列】
    for (long i = 0; i < 6; i++) {
        dispatch_group_async(group, queue, ^{
            NSLog(@"任务%ld，%@", i, [NSThread currentThread]);
        });
    }
    // 当group中的所有任务都执行结束后，执行notify中的任务
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"任务notify，%@", [NSThread currentThread]);
    });
    
    NSLog(@"任务end, %@", [NSThread currentThread]);
}

/// dispatch_group_wait
- (void)groupWait {
    NSLog(@"任务start, %@", [NSThread currentThread]);
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 【异步线程 + 并发队列】
    for (long i = 0; i < 6; i++) {
        dispatch_group_async(group, queue, ^{
            NSLog(@"任务%ld，%@", i, [NSThread currentThread]);
        });
    }
    /**
        DISPATCH_TIME_FOREVER，阻塞线程，即，当group中的所有任务执行完成之后，才执行 dispatch_group_wait 之后的操作
        DISPATCH_TIME_NOW，不阻塞线程，立即执行 dispatch_group_wait 之后的操作
     */
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    NSLog(@"任务end, %@", [NSThread currentThread]);
}

/// dispatch_group_enter + dispatch_group_leave => dispatch_group_async
- (void)groupEnterAndLeave {
    NSLog(@"任务start, %@", [NSThread currentThread]);
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 【异步线程 + 并发队列】
    for (long i = 0; i < 6; i++) {
        dispatch_group_enter(group);
        dispatch_async(queue, ^{
            NSLog(@"任务%ld，%@", i, [NSThread currentThread]);
            dispatch_group_leave(group);
        });
    }
    
    // 当group中的所有任务都执行结束后，执行notify中的任务
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"任务notify，%@", [NSThread currentThread]);
    });
    
    NSLog(@"任务end, %@", [NSThread currentThread]);
}

/**
    dispatch_semaphore_create：创建一个 Semaphore 并初始化信号的总量
    dispatch_semaphore_signal：发送一个信号，让信号总量加 1
    dispatch_semaphore_wait：可以使总信号量减 1，信号总量小于 0 时就会一直等待（阻塞所在线程），否则就可以正常执行。
 */

/// semaphore：1. 保持线程同步，将异步任务转换为同步任务
- (void)semaphoreSync {
    NSLog(@"任务start, %@", [NSThread currentThread]);
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 创建dispatch_semaphore_t变量，信号总量为0
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    dispatch_async(queue, ^{
        NSLog(@"任务1，%@", [NSThread currentThread]);
        // semaphore的信号总量加1
        dispatch_semaphore_signal(semaphore);
    });
    
    // semaphore的信号总量为0，wait后会减1，变成-1，小于0于是会阻塞当前线程
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"任务end, %@", [NSThread currentThread]);
}

/// semaphore：2. 保证线程安全，为线程加锁
- (void)semaphoreSafe {
    NSLog(@"任务start, %@", [NSThread currentThread]);
    
    _ticketSemaphore = dispatch_semaphore_create(1);
    _ticketCount = 30;
    dispatch_queue_t queue1 = dispatch_queue_create("cc.queue1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queue2 = dispatch_queue_create("cc.queue2", DISPATCH_QUEUE_SERIAL);
    
    __weak typeof(self) _self = self;
    dispatch_async(queue1, ^{
        __strong typeof(_self) self = _self;
        [self saleTickets];
    });
    dispatch_async(queue2, ^{
        __strong typeof(_self) self = _self;
        [self saleTickets];
    });
    
    NSLog(@"semaphoreSafe---end, %@", [NSThread currentThread]);
}

- (void)saleTickets {
    while (1) {
        // 相当于加锁
        dispatch_semaphore_wait(_ticketSemaphore, DISPATCH_TIME_FOREVER);
        
        if (_ticketCount > 0) {
            _ticketCount--;
            NSLog(@"剩余票数：%ld, 窗口：%@", (long)_ticketCount, [NSThread currentThread]);
            [NSThread sleepForTimeInterval:0.2];
        }
        else {
            NSLog(@"车票已卖完");
            break ;
        }
        
        // 相当于解锁
        dispatch_semaphore_signal(_ticketSemaphore);
    }
}

@end
