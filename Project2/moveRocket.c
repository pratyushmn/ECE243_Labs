#include <stdbool.h> 
#include <stdio.h> 
#include <stdlib.h> 
#include <math.h>

typedef struct { 
 int x; 
 int y; 
 int width; 
 int speed;  
 short int color;  
} Obstacle; 
 
 
int maxX = 319; 
int maxY = 239; 
int totalObjects = 8;  
Obstacle ob1[8]; 
int finalScore; 
short int colors[8] = {0x001F, 0xF800, 0x07E0, 0x07FF, 0xF81F, 0xFFE0, 0xFFFF, 0xF011}; 
int yLoc[8] = {10, 50, 80, 120, 140, 170, 200, 210};
int shield = 7; 


extern short BACKGROUND[240][320];
extern short GAMEOVER[240][320];
extern short ROCKET[13][35];
extern short START[240][320];

volatile int pixelBufferStart; 
volatile short * pixelbuf; 
unsigned int bitCodes[10] = {0b00111111, 0b00000110, 0b01011011, 0b01001111, 0b01100110, 0b01101101, 0b01111100, 0b00000111, 0b01111111, 0b01100111}; 
volatile int* hexAddress = (int*) 0xFF200020; 


void plot_pixel(int x, int y, short int line_color);
void wait_for_vsync();
void drawRocket(int x, int y);
void clearRocket(int x, int y);
void plot_background();
void createObstacles(); 
void drawObstacles(); 
void drawBoxA(int x, int y, int width, short int color); 
void draw();
void clear_screen();
void draw_line(int x0, int y0, int x1, int y1, short int line_color);
void swap(int* numberA, int* numberB);
void score(int value);
bool checkIfGameOver(int rocketX, int rocketY, int height, int width); 
void gameOver();
void start_screen();

int main () {
    volatile int* RLEDs = (int*) 0xFF200000;
    volatile int* pixelCtrlPtr = (int*) 0xFF203020;
    volatile int* keyPtr = (int*) 0xFF20005C;

    *(pixelCtrlPtr + 1) = 0xC8000000;
	wait_for_vsync();
	pixelbuf = *pixelCtrlPtr;
	pixelBufferStart = *pixelCtrlPtr; 
    unsigned char keyData;

    int rocketPositionY = 0;
    int rocketPositionX = 2;
	
    int prevY = rocketPositionY;
	
    int keyChange = 0;
	finalScore = 0; 
	shield = 7;
	
	createObstacles();
	
    start_screen(); 
	*hexAddress = (0b00111111001111110011111100111111);
	
	while(1) {
		keyData = *(keyPtr);
		if(keyData != 0) {
			*(keyPtr) = keyData; 
			break; 
		}
	}
	
	clear_screen(); 
	
    while (1) {
		keyData = *(keyPtr);			
		if (keyData == 1) {
			rocketPositionY -= 5;
			if (rocketPositionY < 0) rocketPositionY = 0;
			*(keyPtr) = 1;
			keyChange = 1;
		} else if (keyData == 2) {
			rocketPositionY += 5;
			if (rocketPositionY > 225) rocketPositionY = 225;
			*(keyPtr) = 2;
			keyChange = 1;
		}

		if(keyChange) {
			clearRocket(rocketPositionX, prevY);
			prevY = rocketPositionY;
			keyChange = 0;
		}
		draw(); 
		drawRocket(rocketPositionX, rocketPositionY);
		
		score(finalScore);
		
		if(checkIfGameOver(rocketPositionX, rocketPositionY, 15, 40)) {
			shield = shield - 1; 
			if(shield < 0) break; 
		}
		
		if(shield == 7) *RLEDs = 127;
		else if(shield == 6) *RLEDs = 63;
		else if(shield == 5) *RLEDs = 31;
		else if(shield == 4) *RLEDs = 15;
		else if(shield == 3) *RLEDs = 7; 
		else if(shield == 2) *RLEDs = 3;
		else if(shield == 1) *RLEDs = 1;
		else if(shield == 0) *RLEDs = 0; 
		else if(shield < 0) {
			*RLEDs = 0;
			break; 
		}
		
		
		wait_for_vsync(); 
		//pixelBufferStart = *(pixelCtrlPtr + 1); // new back buffer
    }
	
	*RLEDs = 0;
	gameOver();
	
	while(1) {
		keyData = *(keyPtr);
		if(keyData != 0) {
			*(keyPtr) = keyData; 
			main(); 
		}
	}
}

void draw() { 
	//clear_screen(); 
	drawObstacles(); 
} 

void clear_screen() { 
    for(int x = 0; x <= maxX; x++) { 
        for(int y = 0; y <= maxY; y++) { 
            plot_pixel(x,y, 0x0000);  
        } 
    } 
}
 

void plot_pixel(int x, int y, short int line_color) {
	if ((x >= 0) && (x < 320) && (y >= 0) && (y < 240)) {
        *(short int *)(pixelBufferStart + (y << 10) + (x << 1)) = line_color;
	}    
}

void wait_for_vsync() {  
	volatile int* pixelCtrlPtr = (int*) 0xFF203020; 
	
	/* Read location of the pixel buffer from the pixel buffer controller */ 
	register int status;   

	*pixelCtrlPtr = 1;  
	status = *(pixelCtrlPtr + 3);  
	while((status & 0x01) != 0) { 
		status = *(pixelCtrlPtr + 3);  
	} 
} 

void drawRocket(int x, int y) {
    int i, j;

    for (i = 0; i < 13; i++) {
        for (j = 0; j < 35; j++) {
            plot_pixel(j + x, i + y, ROCKET[i][j]);
        }
    }
}

void clearRocket(int x, int y) {
    int i, j;

    for (i = 0; i < 13; i++) {
        for (j = 0; j < 35; j++) {
            plot_pixel(j + x, i + y, 0x0000/*BACKGROUND[i+y][j+x]*/);
        }
    }
}

void plot_background() {
    int i, j;
    
    for (i = 0; i < 240; i++) {
        for (j = 0; j < 320; j++) {
            plot_pixel(j, i, 0x0000);
        }
    }
}

void createObstacles() { 
    for(int index = 0; index < totalObjects; index++) { 
        int width = rand() % 20 + 10; 
        while(width == 0) width = rand() % 10;  
        ob1[index].width = width; 
        ob1[index].x = maxX - ob1[index].width;  
        ob1[index].y = yLoc[index];  
        ob1[index].speed = rand() % 7; 
        while(ob1[index].speed  == 0) ob1[index].speed = rand() % 7; 
        ob1[index].color = colors[index];  
    } 
} 
 
 
void drawObstacles() { 
    for(int index = 0; index < totalObjects; index++) { 
		drawBoxA(ob1[index].x, ob1[index].y, ob1[index].width, 0x0000);
        if (ob1[index].x + ob1[index].speed  < 0) { 
            ob1[index].x = maxX - ob1[index].width;  
            ob1[index].y = yLoc[index];  
			finalScore++; 
        } else { 
            ob1[index].x -= ob1[index].speed;  
        } 
        drawBoxA(ob1[index].x, ob1[index].y, ob1[index].width, ob1[index].color);  
    }
}  
 
void drawBoxA(int x, int y, int width, short int color) { 
    draw_line(x, y, x + width, y, color); 
} 

void draw_line(int x0, int y0, int x1, int y1, short int line_color) { 
    bool is_steep = (abs(y1 - y0) > abs(x1 - x0)); 
    if (is_steep) { 
        swap(&x0, &y0); 
        swap(&x1, &y1); 
    } 
    if (x0 > x1) { 
       swap(&x0, &x1); 
        swap(&y0, &y1); 
   } 
   int delta_x = x1 - x0; 
   int delta_y = abs(y1 - y0); 
   int error = -(delta_x / 2); 
    int y = y0; 
    int y_step; 
    if (y0 < y1) y_step = 1; 
    else y_step = -1; 
    for (int x = x0; x <= x1; x++) { 
        if (is_steep) { 
            plot_pixel(y, x, line_color); 
        } 
        else { 
            plot_pixel(x, y, line_color); 
        } 
        error += delta_y; 
        if (error >= 0) { 
            y += y_step; 
            error -= delta_x; 
        } 
    } 
} 
 
 
void swap(int* numberA, int* numberB) { 
    int temp = *numberA; 
    *numberA = *numberB; 
    *numberB = temp;  
} 

void score(int value) { 
    int digitNum = 0; 
    int digit = 0; 
    unsigned int hexCode; 
	unsigned int hexValue = 0;
	int i = 0;
    if (value > 9999) value = 9999; 
	
	//bool insertZero = false;
	//if(value % 10 == 0) insertZero = true; 
	
    while (value != 0) { 
        digit = value % 10; 
        hexCode = bitCodes[digit]; 
        value = (int) value/10;
		hexCode = hexCode << 8*i;
		hexValue = hexValue + hexCode;
		i++;
    } 
	
	/*if (insertZero) {
		hexCode = bitCodes[0];
		hexCode = hexCode << 8*i;
		hexValue = hexValue + hexCode;
	}*/
	
	*hexAddress = hexValue; 
} 

bool checkIfGameOver(int rocketX, int rocketY, int height, int width) {
	for(int index = 0; index < totalObjects; index++) {
		if(ob1[index].x <= rocketX + width && (ob1[index].y >= rocketY && ob1[index].y <= rocketY + height)) {
			drawBoxA(ob1[index].x, ob1[index].y, ob1[index].width, 0x0000);
			ob1[index].x = maxX - ob1[index].width;  
            ob1[index].y = yLoc[index];
			return 1; 
		}
	}
	return 0; 
}	

void gameOver() {
	for (int i = 0; i < 240; i++) {
		for (int j = 0; j < 320; j++) {
			plot_pixel(j, i, GAMEOVER[i][j]);
		}
	}
}

void start_screen() {
	for (int i = 0; i < 240; i++) {
		for (int j = 0; j < 320; j++) {
			plot_pixel(j, i, START[i][j]);
		}
	}
}
