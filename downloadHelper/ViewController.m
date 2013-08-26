//
//  ViewController.m
//  downloadHelper
//
//  Created by Jonathan Dring on 24/08/2013.
//  Copyright (c) 2013 Jonathan Dring. All rights reserved.
//

#import "ViewController.h"
#import <AWSRuntime/AWSRuntime.h>
#import <AWSS3/AmazonS3Client.h>



@interface ViewController ()

@end

@implementation ViewController 

- (void)viewDidLoad
{

    
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    
    self.label.text= @"active";
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
