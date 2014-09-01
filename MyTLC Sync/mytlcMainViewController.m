/*
 * Copyright 2013 Devin Collins <devin@imdevinc.com>
 * Copyright 2014 Mike Wohlrab <Mike@NeoNet.me>
 *
 * This file is part of MyTLC Sync.
 *
 * MyTLC Sync is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * MyTLC Sync is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with MyTLC Sync.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "mytlcMainViewController.h"
#import "mytlcCalendarHandler.h"
#import "KeychainItemWrapper.h"
#import <Security/Security.h>


@interface mytlcMainViewController ()

@end

@implementation mytlcMainViewController

@synthesize btnLogin;
@synthesize txtPassword;
@synthesize txtUsername;
@synthesize aivStatus;
@synthesize lblStatus;
@synthesize chkSave;
@synthesize scrollView;


mytlcCalendarHandler* ch = nil;
BOOL showNotifications = NO;
- (void) checkStatus
{
    while (![ch hasCompleted])
    {
        if (![ch hasNewMessage]){
            continue;
        }
        
        [ch setMessageRead];
        
        [self performSelectorOnMainThread:@selector(displayMessage) withObject:FALSE waitUntilDone:false];
    }
}

- (void) deleteEvent
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults removeObjectForKey:@"shifts"];
    
    [defaults synchronize];
    
    [lblStatus setText:@"Events cache cleared, remove events from the calendar manually"];
}

- (void) displayAlert:(NSString*) message
{
    UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"MyTLC Sync" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil];
    
    [alert show];
}

- (void) displayMessage
{
    [lblStatus setText:[ch getMessage]];

    if ([ch hasCompleted])
    {
        if (showNotifications)
        {
            UILocalNotification* notification = [[UILocalNotification alloc] init];
            
            notification.fireDate = [NSDate date];
            
            notification.alertBody = [ch getMessage];
            
            notification.timeZone = [NSTimeZone defaultTimeZone];
            
            [[UIApplication sharedApplication] scheduleLocalNotification:notification];
        }
        
        [aivStatus stopAnimating];
        
        [btnLogin setEnabled:YES];
        
        if (self.fetchCompletionHandler)
        {
            self.fetchCompletionHandler(UIBackgroundFetchResultNewData);
            
            self.fetchCompletionHandler = nil;
        }
    }
}

- (IBAction) hideKeyboard
{
    [txtUsername resignFirstResponder];
    [txtPassword resignFirstResponder];
    [scrollView setContentOffset:CGPointMake(0,0) animated:YES];
}

- (void) autologin:(void (^)(UIBackgroundFetchResult))completionHandler
{
    
    // testing using mytlcMainViewController
    KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"MyTLCSyncLoginCreds" accessGroup:nil];
    // sets string username and password to that from the keychain
    NSString *username = [keychainItem objectForKey:(__bridge id)(kSecAttrAccount)];
    NSString *password = [keychainItem objectForKey:(__bridge id)(kSecValueData)];
    
    self.fetchCompletionHandler = completionHandler;
    
    showNotifications = YES;
    
    [self login:username password:password];
}

- (IBAction) manualLogin
{
    [self hideKeyboard];
    
    [lblStatus setText:@""];
    
    // If username or password is blank then alert user
    if ([txtUsername.text isEqualToString:@""] || [txtPassword.text isEqualToString:@""])
    {
        [self displayAlert:@"Please enter a username and password"];
        
        return;
    }
    
    // If user lets us save the creds, then keep them saved
    if ([chkSave isOn]) {
    
        // Sets Username and Password to data from the text field
        KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"MyTLCSyncLoginCreds" accessGroup:nil];
        [keychainItem setObject:[txtUsername text] forKey:(__bridge id)(kSecAttrAccount)];
        [keychainItem setObject:[txtPassword text] forKey:(__bridge id)(kSecValueData)];
        
    // Otherwise remove them from keychain
    } else {
        
        KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"MyTLCSyncLoginCreds" accessGroup:nil];
        [keychainItem resetKeychainItem];
    }
    
    NSString *username = [txtUsername text];
    NSString *password = [txtUsername text];
    
    [self login:username password:password];
}

- (void)login:(NSString*)username password:(NSString*) password
{
    NSDictionary *login = [[NSDictionary alloc] initWithObjectsAndKeys:username, @"username", password, @"password", nil];
    
    [btnLogin setEnabled:NO];
    
    [aivStatus startAnimating];
    
    NSOperationQueue* backgroundQueue = [NSOperationQueue new];
    
    ch = [[mytlcCalendarHandler alloc] init];
    
    NSInvocationOperation* operation = [[NSInvocationOperation alloc] initWithTarget:ch selector:@selector(runEvents:) object:login];
    
    [backgroundQueue addOperation:operation];
    
    operation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(checkStatus) object:nil];
    
    [backgroundQueue addOperation:operation];
}

- (BOOL) textFieldShouldReturn:(UITextField*) textField
{
    if ([textField isEqual:txtUsername])
    {
        [textField resignFirstResponder];
        [txtPassword becomeFirstResponder];
        return NO;
    } else {
        [textField resignFirstResponder];
        [scrollView setContentOffset:CGPointMake(0,0) animated:YES];
        [self manualLogin];
    }
    
    return YES;
}

- (IBAction)unwindToMain:(UIStoryboardSegue *)segue
{

}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void) textFieldDidBeginEditing:(UITextField*) textField
{
    [scrollView setContentOffset:CGPointMake(0, txtUsername.center.y - 120) animated:YES];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    UIGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)];
    
    [self.view addGestureRecognizer:tap];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    BOOL firstRun = ![defaults boolForKey:@"firstRun"];
    
    // Removed Version and Changelog notification
    
    if (firstRun) {
        [defaults setBool:YES forKey:@"firstRun"];
        
        [defaults setValue:@"default" forKey:@"calendar_id"];
        
        [defaults setInteger:0 forKey:@"alarm"];
        
        [defaults setInteger:7 forKey:@"sync_day"];
        
        [defaults setValue:@"12:00 AM" forKey:@"sync_time"];
        
        [defaults setValue:@"Work @ Best Buy" forKey:@"title"];
        
        [defaults synchronize];
    } else {
        
        // sets string username and password to that from the keychain
        KeychainItemWrapper *keychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"MyTLCSyncLoginCreds" accessGroup:nil];
        NSString *username = [keychainItem objectForKey:(__bridge id)(kSecAttrAccount)];
        NSString *password = [keychainItem objectForKey:(__bridge id)(kSecValueData)];
        
        if (username != nil && password != nil) {
            [txtUsername setText:username];
            
            [txtPassword setText:password];
            
            
            [chkSave setOn:YES];
        } else {
            [chkSave setOn:NO];
        }
    }
    
}

- (void) viewDidAppear:(BOOL)animated
{
    [scrollView setContentOffset:CGPointMake(0,0) animated:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

