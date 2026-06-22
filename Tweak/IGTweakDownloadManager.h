#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface IGTweakDownloadManager : NSObject
+ (void)downloadImage:(UIImage *)image;
+ (void)downloadVideoFromURL:(NSURL *)url;
+ (UIButton *)createDownloadButtonWithTarget:(id)target action:(SEL)action;
@end
