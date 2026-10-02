#include <SDL3/SDL.h>
#include <SDL3_shadercross/SDL_shadercross.h>
#include <stdio.h>

int main(void) {
	if (SDL_GetVersion() != SDL_VERSION) {
		fprintf(stderr, "SDL header/library version mismatch\n");
		return 1;
	}
	if (!SDL_Init(0)) {
		fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
		return 1;
	}
	if (SDL_GetPerformanceFrequency() == 0 || SDL_GetPerformanceCounter() == 0) {
		fprintf(stderr, "SDL performance clock unavailable\n");
		SDL_Quit();
		return 1;
	}
	SDL_Surface *surface = SDL_CreateSurface(2, 2, SDL_PIXELFORMAT_RGBA32);
	if (surface == NULL) {
		fprintf(stderr, "SDL_CreateSurface: %s\n", SDL_GetError());
		SDL_Quit();
		return 1;
	}
	SDL_DestroySurface(surface);
	if (!SDL_ShaderCross_Init()) {
		fprintf(stderr, "SDL_ShaderCross_Init: %s\n", SDL_GetError());
		SDL_Quit();
		return 1;
	}
	if (SDL_ShaderCross_GetSPIRVShaderFormats() == 0) {
		fprintf(stderr, "Shadercross has no SPIR-V output formats\n");
		SDL_ShaderCross_Quit();
		SDL_Quit();
		return 1;
	}
	SDL_ShaderCross_Quit();
	SDL_Quit();
	printf("SDL %d: clock, surface, shadercross OK\n", SDL_GetVersion());
	return 0;
}
