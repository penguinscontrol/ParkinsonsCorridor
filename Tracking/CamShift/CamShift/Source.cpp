#include "opencv2/video/tracking.hpp"
#include "opencv2/imgproc/imgproc.hpp"
#include "opencv2/highgui/highgui.hpp"
#include <iostream>
#include <fstream>
#include <ctype.h>

using namespace cv;
using namespace std;

Mat image, mask, mask3ch, hsv;
RotatedRect red_trackBox, blu_trackBox;
Rect red_trackWindow, blu_trackWindow;
Point red_last_coord, blu_last_coord;


Size r = Size(600, 250);
int red_timeout = 0;
int blu_timeout = 0;
int waitframes = 4; // must be an even number
Mat frame, hue, red_backproj, blu_backproj;
Mat red_temp, blu_temp, red_amp_mask, blu_amp_mask;

bool paused = false;

int dt = 3;
int backprojMode = 0;
bool selectObject = false;
int trackRed = 0;
int trackBlu = 0;
bool showHist = true;
Point origin;
Rect selection;
bool redsel = true;
bool blusel = false;
int vmin = 10, vmax = 256, smin = 50;
int redhmin = 160, redhmax = 180, bluhmin = 80, bluhmax = 100;
int ampthresh = 20;
int kernel_size = 41;

// Histogram stuff
int h_bins = 180;
int s_bins = 255;
// bins must be > 2
int histSize[] = { h_bins, s_bins };

float red_h_range[] = { redhmin, redhmax };
float blu_h_range[] = { bluhmin, bluhmax };

float s_range[] = { smin, 255 };

const float* red_ranges[] = { red_h_range, s_range };
const float* blu_ranges[] = { blu_h_range, s_range };
int channels[] = { 0, 1 };

Mat red_hist, red_hist_img, blu_hist, blu_hist_img;

class location_data{
	int key;
	double value;
};

static void help()
{
	std::cout << "\nThis is a demo that shows mean-shift based tracking\n"
		"You select a color objects such as your face and it tracks it.\n"
		"This reads from video camera (0 by default, or the camera number the user enters\n"
		"Usage: \n"
		"   ./camshiftdemo [camera number]\n";

	std::cout << "\n\nHot keys: \n"
		"\tESC - quit the program\n"
		"\tc - stop the tracking\n"
		"\tf - switch to/from red backprojection view\n"
		"\td - switch to/from blue backprojection view\n"
		"\th - reset object histograms\n"
		"\tp - pause video\n"
		"\tr - select red paw\n"
		"\tb - select blue paw\n"
		"To initialize tracking, select the object with mouse\n";
}

const char* keys =
{
	"{1|  | 0 | camera number}"
};

static void onMouse(int event, int x, int y, int, void*)
{
	if (selectObject)
	{
		selection.x = MIN(x, origin.x);
		selection.y = MIN(y, origin.y);
		selection.width = std::abs(x - origin.x);
		selection.height = std::abs(y - origin.y);

		selection &= Rect(0, 0, image.cols, image.rows);
	}

	switch (event)
	{
	case CV_EVENT_LBUTTONDOWN:
		origin = Point(x, y);
		selection = Rect(x, y, 0, 0);
		selectObject = true;
		break;
	case CV_EVENT_LBUTTONUP:
		selectObject = false;
		if (selection.width > 0 && selection.height > 0)
			if (redsel){
				red_trackWindow = selection;
				red_last_coord = Point(origin.x + selection.width / 2, origin.y + selection.height / 2);
				trackRed = -1;
				std::cout << "Made red selection\n";
			}
			else if (blusel){
				blu_trackWindow = selection;
				blu_last_coord = Point(origin.x + selection.width / 2, origin.y + selection.height / 2);
				trackBlu = -1;
				cout << "Made blue selection\n";
			}
		break;
	}
}

static Rect reset_trackWindow(Point last_coord){
	Rect trackWindow = Rect(MAX(0, last_coord.x - r.width / 2), MAX(0, last_coord.y - r.height / 2),
		last_coord.x + r.width / 2, last_coord.y + r.height / 2);
	return trackWindow;
}
static Mat gethistogram(Mat temp, bool redhist){
	Mat hist, temp_hsv;
	cvtColor(temp, temp_hsv, COLOR_BGR2HSV);

	if (redhist){
		calcHist(&temp_hsv, 1, channels, Mat(), hist, 2, histSize, red_ranges, true, false);
	}
	else{
		calcHist(&temp_hsv, 1, channels, Mat(), hist, 2, histSize, blu_ranges, true, false);
	}

	normalize(hist, hist, 0, 255, NORM_MINMAX, -1);
	return hist;
}

void reset_histograms(void){
	red_h_range[0] = redhmin;
	red_h_range[1] = redhmax;
	blu_h_range[0] = bluhmin;
	blu_h_range[1] = bluhmax;

	s_range[0] = smin;

	red_hist = gethistogram(red_temp, true);
	cvtColor(red_hist, red_hist_img, COLOR_GRAY2BGR);
	imshow("Red Histogram", red_hist_img);
	blu_hist = gethistogram(blu_temp, false);
	cvtColor(blu_hist, blu_hist_img, COLOR_GRAY2BGR);
	imshow("Blue Histogram", blu_hist_img);

}

int main(int argc, const char** argv)
{
	help();

	VideoCapture cap;
	ofstream redXYfile("redXYfile.bin", ios::binary);
	ofstream bluXYfile("bluXYfile.bin", ios::binary);
	/*
	int hsize = 16;
	float hranges[] = { 0, 180 };
	const float* phranges = hranges;
	CommandLineParser parser(argc, argv, keys);
	int camNum = parser.get<int>("1");
	*/

	namedWindow("CamShift Demo", 0);
	setMouseCallback("CamShift Demo", onMouse, 0);
	createTrackbar("Vmin", "CamShift Demo", &vmin, 256, 0);
	createTrackbar("Vmax", "CamShift Demo", &vmax, 256, 0);
	createTrackbar("RedHmin", "CamShift Demo", &redhmin, 180, 0);
	createTrackbar("RedHmax", "CamShift Demo", &redhmax, 180, 0);
	createTrackbar("BluHmin", "CamShift Demo", &bluhmin, 180, 0);
	createTrackbar("BluHmax", "CamShift Demo", &bluhmax, 180, 0);
	createTrackbar("Smin", "CamShift Demo", &smin, 256, 0);
	createTrackbar("Amplitude Threshold", "CamShift Demo", &ampthresh, 256, 0);
	createTrackbar("Speed", "CamShift Demo", &dt, 200, 0);
	namedWindow("Red Histogram", WINDOW_NORMAL);
	namedWindow("Blue Histogram", WINDOW_NORMAL);

	if (argc > 1){
		cap.open(string(argv[1]));
	}
	else {
		char* def_video = "C:\\Users\\Radu Darie\\Google Drive\\ODBS\\practice_video\\Leon_Tunnel_2.mpg";
		//cap.open(def_video); // open the default video stream
		cap.open(1); // open the webcam
	}

	if (!cap.isOpened())
	{
		help();
		std::cout << "***Could not initialize capturing...***\n";
		std::cout << "Current parameter's value: \n";
		return -1;
	}
	
	if (argc > 2) {
		red_temp = imread(argv[2], 1);
		blu_temp = imread(argv[3], 1);
	}
	else {
		char* def_templ = "C:\\Users\\Radu Darie\\Google Drive\\ODBS\\OpenCV\\Tutorials\\Screenshots\\red.png";
		red_temp = imread(def_templ, 1);
		def_templ = "C:\\Users\\Radu Darie\\Google Drive\\ODBS\\OpenCV\\Tutorials\\Screenshots\\blue.png";
		blu_temp = imread(def_templ, 1);
	}
		
	/* Draw Histograms
	To Do: make histograms reflect hue
	*/
	reset_histograms();

	for (;;)
	{

		if (!paused)
		{
			cap >> frame;
			//cout << "\n\nRunning \n";
			if (frame.empty())
				break;
		}

		frame.copyTo(image);

		if (!paused)
		{

				int _vmin = vmin, _vmax = vmax;
				cvtColor(image, hsv, COLOR_BGR2HSV);
				inRange(hsv, Scalar(0, smin, MIN(_vmin, _vmax)),
					Scalar(180, 256, MAX(_vmin, _vmax)), mask);

				vector<Mat> hsvchan;
				split(hsv, hsvchan);
				bitwise_and(hsvchan[0], mask, hsvchan[0]);
				bitwise_and(hsvchan[1], mask, hsvchan[1]);
				bitwise_and(hsvchan[2], mask, hsvchan[2]);
				merge(hsvchan, hsv);
			
			
				if (trackRed){

					calcBackProject(&hsv, 1, channels, red_hist, red_backproj, red_ranges, 1, true);
					red_backproj.copyTo(red_amp_mask);

					GaussianBlur(red_amp_mask, red_amp_mask, Size(kernel_size, kernel_size), 0, 0);
					threshold(red_amp_mask, red_amp_mask, ampthresh, 255, THRESH_BINARY);
					bitwise_and(red_backproj, red_amp_mask, red_backproj);

					if (red_timeout == 0){
						if (trackRed == -1){
							red_trackBox = CamShift(red_backproj, red_trackWindow,
								TermCriteria(CV_TERMCRIT_EPS | CV_TERMCRIT_ITER, 500, 0.001));
							trackRed = 1;
						}
						else if (trackRed == 1){
							Rect cur_bound = red_trackBox.boundingRect();
							red_trackBox = CamShift(red_backproj, cur_bound,
								TermCriteria(CV_TERMCRIT_EPS | CV_TERMCRIT_ITER, 500, 0.001));
						}
					}

					if (red_trackBox.size.area() <= 1 && red_timeout == 0)
					{
						cout << "Red foot swing";
						red_timeout = waitframes;
						red_trackWindow = reset_trackWindow(red_last_coord);
					}
					else if (red_trackBox.size.area() <= 1 && red_timeout > 1){
						red_timeout--;
					}

					if (red_trackBox.size.area() <= 1 && red_timeout == 1){
						red_trackBox = CamShift(red_backproj, red_trackWindow,
							TermCriteria(CV_TERMCRIT_EPS | CV_TERMCRIT_ITER, 500, 0.001));

						if (red_trackBox.size.area() >= 1){
							red_timeout = 0;
						}
						else{
							red_trackWindow = reset_trackWindow(red_last_coord);
							red_timeout = waitframes / 2;
						}
					}


					if (red_trackBox.size.area() >= 1){
						red_last_coord = red_trackBox.center;
						int xcoord = red_trackBox.center.x;
						redXYfile.write((char *)&xcoord, sizeof(xcoord));
						int ycoord = red_trackBox.center.y;
						redXYfile.write((char *)&ycoord, sizeof(ycoord));
					}
					else{
						int dummycoord = 5000;
						redXYfile.write((char *)&dummycoord, sizeof(dummycoord));
						redXYfile.write((char *)&dummycoord, sizeof(dummycoord));
					}
				} // end if track red
				else{
					int dummycoord = 10000;
					redXYfile.write((char *)&dummycoord, sizeof(dummycoord));
					redXYfile.write((char *)&dummycoord, sizeof(dummycoord));
				}

				if (trackBlu){

					calcBackProject(&hsv, 1, channels, blu_hist, blu_backproj, blu_ranges, 1, true);
					blu_backproj.copyTo(blu_amp_mask);

					GaussianBlur(blu_amp_mask, blu_amp_mask, Size(kernel_size, kernel_size), 0, 0);
					threshold(blu_amp_mask, blu_amp_mask, ampthresh, 255, THRESH_BINARY);
					bitwise_and(blu_backproj, blu_amp_mask, blu_backproj);

					if (blu_timeout == 0){
						if (trackBlu == -1){
							blu_trackBox = CamShift(blu_backproj, blu_trackWindow,
								TermCriteria(CV_TERMCRIT_EPS | CV_TERMCRIT_ITER, 500, 0.001));
							trackBlu = 1;
						}
						else if (trackBlu == 1){
							Rect blu_cur_bound = blu_trackBox.boundingRect();
							blu_trackBox = CamShift(blu_backproj, blu_cur_bound,
								TermCriteria(CV_TERMCRIT_EPS | CV_TERMCRIT_ITER, 500, 0.001));
						}
					}

					if (blu_trackBox.size.area() <= 1 && blu_timeout == 0)
					{
						blu_timeout = waitframes;
						std::cout << "Blue foot swing";
						blu_trackWindow = reset_trackWindow(blu_last_coord);
					}
					else if (blu_trackBox.size.area() <= 1 && blu_timeout > 1)
					{
						blu_timeout--;
					}

					if (blu_trackBox.size.area() <= 1 && blu_timeout == 1){
						blu_trackBox = CamShift(blu_backproj, blu_trackWindow,
							TermCriteria(CV_TERMCRIT_EPS | CV_TERMCRIT_ITER, 500, 0.001));

						if (blu_trackBox.size.area() >= 1){
							blu_timeout = 0;
						}
						else{
							blu_trackWindow = reset_trackWindow(blu_last_coord);
							blu_timeout = waitframes / 2;
						}
					}

					if (blu_trackBox.size.area() >= 1){
						blu_last_coord = blu_trackBox.center;
						int xcoord = blu_trackBox.center.x;
						bluXYfile.write((char *)&xcoord, sizeof(xcoord));
						int ycoord = blu_trackBox.center.y;
						bluXYfile.write((char *)&ycoord, sizeof(ycoord));
					}
					else{
						int dummycoord = 5000;
						bluXYfile.write((char *)&dummycoord, sizeof(dummycoord));
						bluXYfile.write((char *)&dummycoord, sizeof(dummycoord));
					}
				} // end if track blue
				else{
					int dummycoord = 10000;
					bluXYfile.write((char *)&dummycoord, sizeof(dummycoord));
					bluXYfile.write((char *)&dummycoord, sizeof(dummycoord));
				}

				if (backprojMode == 1)
					cvtColor(red_backproj, image, COLOR_GRAY2BGR);
				else if (backprojMode == 2)
					cvtColor(blu_backproj, image, COLOR_GRAY2BGR);

				if (red_timeout == 0 && red_trackBox.size.area() >= 1){
					ellipse(image, red_trackBox, Scalar(255, 0, 255), 3, CV_AA);
					circle(image, red_trackBox.center, 1, Scalar(255, 0, 255), 5, 1, 0);
				}
				else if (trackRed){
					RotatedRect wheretolook = RotatedRect(red_last_coord, r, 0);
					ellipse(image, wheretolook, Scalar(0, 0, 255), 3, CV_AA);
				}

				if (blu_timeout == 0 && blu_trackBox.size.area() >= 1){
					ellipse(image, blu_trackBox, Scalar(255, 255, 0), 3, CV_AA);
					circle(image, blu_trackBox.center, 1, Scalar(255, 255, 0), 5, 1, 0);
				}
				else if (trackBlu){
					RotatedRect wheretolook = RotatedRect(blu_last_coord, r, 0);
					ellipse(image, wheretolook, Scalar(255, 0, 0), 3, CV_AA);
				}
		} // end if !paused

		if (selectObject && selection.width > 0 && selection.height > 0)
		{
			Mat roi(image, selection);
			bitwise_not(roi, roi);
		}

		imshow("CamShift Demo", image);

		char c = (char)waitKey(dt);
		if (c == 27)
			break;
		switch (c)
		{
		case 'f':
			if (backprojMode != 2){
				backprojMode = 2;
			}
			else{
				backprojMode = 0;
			}
			break;
		case 'd':
			if (backprojMode != 1){
				backprojMode = 1;
			}
			else{
				backprojMode = 0;
			}
			break;
		case 'c':
			trackRed = 0;
			trackBlu = 0;
			break;
		case 'h':

			reset_histograms();
			break;
		case 'p':
			paused = !paused;
			cout << "\n\nPaused \n";
			break;
		case 'r':
			redsel = true;
			blusel = false;
			cout << "\n Select Red \n";
			break;
		case 'b':
			redsel = false;
			blusel = true;
			cout << "\n Select Blue \n";
			break;
		default:
			;
		}
	}

	return 0;
}
