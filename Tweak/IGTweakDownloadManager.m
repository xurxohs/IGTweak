#import "IGTweakDownloadManager.h"

@implementation IGTweakDownloadManager

+ (void)showSuccessHUD {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Success" message:@"Saved to Camera Roll" preferredStyle:UIAlertControllerStyleAlert];
        
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        [rootVC presentViewController:alert animated:YES completion:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    });
}

+ (void)showErrorHUD:(NSString *)errorMsg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"❌ Error" message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

+ (void)downloadImage:(UIImage *)image {
    if (!image) {
        [self showErrorHUD:@"No image found!"];
        return;
    }
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

+ (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        [self showErrorHUD:error.localizedDescription];
    } else {
        [self showSuccessHUD];
    }
}

+ (void)downloadVideoFromURL:(NSURL *)url {
    if (!url) {
        [self showErrorHUD:@"No video URL found!"];
        return;
    }
    
    // Download video to temp path
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (error || !location) {
            [self showErrorHUD:error.localizedDescription ?: @"Failed to download video"];
            return;
        }
        
        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", [[NSUUID UUID] UUIDString]]];
        NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
        
        NSError *moveError = nil;
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:tempURL error:&moveError];
        
        if (moveError) {
            [self showErrorHUD:moveError.localizedDescription];
            return;
        }
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(tempPath)) {
            UISaveVideoAtPathToSavedPhotosAlbum(tempPath, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
        } else {
            [self showErrorHUD:@"Video is not compatible with Photos album."];
        }
    }];
    [task resume];
}

+ (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        [self showErrorHUD:error.localizedDescription];
    } else {
        [self showSuccessHUD];
    }
    // Clean up temp file
    if (videoPath) {
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
    }
}

+ (UIButton *)createDownloadButtonWithTarget:(id)target action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 44, 44);
    btn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    btn.layer.cornerRadius = 22;
    btn.clipsToBounds = YES;
    btn.tag = 999123; // kDownloadButtonTag
    
    [btn setTitle:@"⬇️" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:20];
    
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    
    return btn;
}

@end
