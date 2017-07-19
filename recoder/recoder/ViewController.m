//
//  ViewController.m
//  recoder
//
//  Created by liuya on 2017/7/17.
//  Copyright © 2017年 liuya. All rights reserved.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>

#import "AFHTTPSessionManager.h"

#import "lame.h"


#define kSandboxPathStr [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]

#define kMp3FileName @"myRecord.mp3"
#define kCafFileName @"myRecord.caf"

@interface ViewController ()<AVAudioRecorderDelegate,AVAudioPlayerDelegate>


@property (nonatomic,copy) NSString *cafPathStr;
@property (nonatomic,copy) NSString *mp3PathStr;

@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) NSMutableDictionary *musices;
@property (nonatomic, strong) AFHTTPSessionManager *mgr;


@end

@implementation ViewController

#pragma mark -  Getter


- (AFHTTPSessionManager *)mgr{

    if (_mgr == nil) {
        
        AFHTTPSessionManager *mgr = [AFHTTPSessionManager manager];
        mgr.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        _mgr = mgr;
    }
    
    return _mgr;
}

// 存放所有的播放器
- (NSMutableDictionary *)musices
{
    if (_musices == nil) {
        _musices = [NSMutableDictionary dictionary];
    }
    return _musices;
}

/**
 *  获得录音机对象
 *
 *  @return 录音机对象
 */
-(AVAudioRecorder *)audioRecorder{
    if (_audioRecorder == nil) {
        
        //创建录音文件保存路径
        NSURL *url = [NSURL URLWithString:self.cafPathStr];
        //创建录音格式设置
        NSDictionary *setting = [self getAudioSetting];
        //创建录音机
        NSError *error = nil;
        
        _audioRecorder = [[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate = self;
        _audioRecorder.meteringEnabled = YES;//如果要监控声波则必须设置为YES
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}



- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.cafPathStr = [kSandboxPathStr stringByAppendingPathComponent:kCafFileName];
    
    self.mp3PathStr =  [kSandboxPathStr stringByAppendingPathComponent:kMp3FileName];
}



/**
 上传视频文件到服务器
 */
- (IBAction)uploadMP3:(id)sender {
    
    // 判断文件的路径是否存在
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.mp3PathStr]) {
    
        // 开始上传，上传到服务器的接口，我这边是用本地测试，
        [self.mgr POST:@"http://127.0.0.1/video" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
            
            NSData *data = [NSData dataWithContentsOfFile:self.mp3PathStr];
            
            [formData appendPartWithFileData:data name:@"file" fileName:@"recorder.mp3" mimeType:@"audio/mpeg"];
            
        } progress:^(NSProgress * _Nonnull uploadProgress) {
            
            
            NSLog(@"--------------");
            
            NSLog(@"uploadProgress = %0.2f",uploadProgress.completedUnitCount *1.0 / uploadProgress.totalUnitCount);
            
        } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
            
            // 上传成功之后，将沙盒中的保存的MP3视频删除
            [self deleteRecordFileWithPath:self.mp3PathStr];
            
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            
            NSLog(@"error = %@",error);
            
        }];
        
    }
    
}


/**
 点击按钮开始录音
 
 */
- (IBAction)startRecorder:(id)sender {
    
    if ([self.audioRecorder isRecording]) {
        
        [self.audioRecorder stop];
    }
    
    NSLog(@"-----------------开始录音---------------");
    
    // 删除原来保存的文件
    [self deleteRecordFileWithPath:self.cafPathStr];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    // 首次使用应用时会询问用户是否允许使用麦克风
    if (![self.audioRecorder isRecording]) {
        
        [self.audioRecorder prepareToRecord];
        [self.audioRecorder record];
    }

}



/**
 点击按钮停止录音

 */
- (IBAction)stopRecorder:(id)sender {
    
    NSLog(@"-------------停止录音--------");
    [self.audioRecorder stop];
    
    
    long long cafFileSize = [self fileSizeAtPath:self.cafPathStr]/1024.0;
    
    NSString *cafFileSizeStr = [NSString stringWithFormat:@"%lld",cafFileSize];
    
    NSLog(@"----cafFileSizeStr = %@----",cafFileSizeStr);
    
    
    // 转成MP3格式
    [self audio_PCMtoMP3];
    
    //计算文件大小
    long long fileSize = [self fileSizeAtPath:self.mp3PathStr]/1024.0;
    NSString *fileSizeStr = [NSString stringWithFormat:@"%lld",fileSize];
    
    NSLog(@"------fileSizeStr = %@",fileSizeStr);
    
    [self deleteRecordFileWithPath:self.cafPathStr];
    
    
}



/**
 播放录音
 */
- (IBAction)playRecorder:(id)sender {
    
    [self playMusicWithUrl:[NSURL URLWithString:self.mp3PathStr]];
    
    
}
/**
 *播放音乐文件
 */
- (BOOL)playMusicWithUrl:(NSURL *)fileUrl
{
    //其他播放器停止播放
    [self stopAllMusic];
    
    if (!fileUrl) return NO;
    
    AVAudioSession *session=[AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];  //此处需要恢复设置回放标志，否则会导致其它播放声音也会变小
    [session setActive:YES error:nil];
    
    AVAudioPlayer *player=[self musices][fileUrl];
    
    if (!player) {
        //2.2创建播放器
        player=[[AVAudioPlayer alloc]initWithContentsOfURL:fileUrl error:nil];
    }
    
    player.delegate = self;
    
    if (![player prepareToPlay]){
        NSLog(@"缓冲失败--");
        //        [self myToast:@"播放器缓冲失败"];
        return NO;
    }
    
    [player play];
    
    //2.4存入字典
    [self musices][fileUrl]=player;
    
    
    NSLog(@"musices:%@ musices",self.musices);
    
    return YES;//正在播放，那么就返回YES
}

// 停止所有的播放器播放音乐
- (void)stopAllMusic
{
    
    if ([self musices].allKeys.count > 0) {
        for ( NSString *playID in [self musices].allKeys) {
            
            AVAudioPlayer *player=[self musices][playID];
            [player stop];
        }
    }
}

#pragma mark - caf转mp3
- (void)audio_PCMtoMP3
{
    
    @try {
        int read, write;
        
        FILE *pcm = fopen([self.cafPathStr cStringUsingEncoding:1], "rb");  //source 被转换的音频文件位置
        fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
        FILE *mp3 = fopen([self.mp3PathStr cStringUsingEncoding:1], "wb");  //output 输出生成的Mp3文件位置
        
        const int PCM_SIZE = 8192;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE*2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_in_samplerate(lame, 11025.0);
        lame_set_VBR(lame, vbr_default);
        lame_init_params(lame);
        
        do {
            read = fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read == 0)
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            else
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
            
            fwrite(mp3_buffer, write, 1, mp3);
            
        } while (read != 0);
        
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
    }
    @catch (NSException *exception) {
        NSLog(@"%@",[exception description]);
    }
    @finally {
        NSLog(@"MP3生成成功: %@",self.mp3PathStr);
    }
    
}

//单个文件的大小
- (long long) fileSizeAtPath:(NSString*)filePath{
    
    NSFileManager* manager = [NSFileManager defaultManager];
    
    if ([manager fileExistsAtPath:filePath]){
        
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
    }
    
    return 0;
}



/**
 根据文件的路径,删除文件

 @param filePath 提供的文件路径
 */
-(void)deleteRecordFileWithPath:(NSString *)filePath{
    
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        
        [fileManager removeItemAtPath:filePath error:nil];
    }
}




/**
 *  取得录音文件设置
 *
 *  @return 录音设置
 */
-(NSDictionary *)getAudioSetting{
    //LinearPCM 是iOS的一种无损编码格式,但是体积较为庞大
    //录音设置
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    //录音格式 无法使用
    [recordSettings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey: AVFormatIDKey];
    //采样率
    [recordSettings setValue :[NSNumber numberWithFloat:11025.0] forKey: AVSampleRateKey];//44100.0
    //通道数
    [recordSettings setValue :[NSNumber numberWithInt:2] forKey: AVNumberOfChannelsKey];
    //线性采样位数
    //[recordSettings setValue :[NSNumber numberWithInt:16] forKey: AVLinearPCMBitDepthKey];
    //音频质量,采样质量
    [recordSettings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
    
    return recordSettings;
}


@end
