// Entry point for the QuickJS bundle. It exports all of `mpl`, registers every
// shipped font face, and loads every shipped colormap so native scripts behave
// like the Node-side API.
export * from "mpl";
import { registerColormapRgba, registerColormaps, registerFonts } from "mpl";
import { allColormapRgba } from "mpl/colormaps/all.rgba";
import { allColormaps } from "mpl/colormaps/all";
import { allFonts } from "mpl/fonts/all";

registerColormaps(...allColormaps);
registerColormapRgba(...allColormapRgba);
registerFonts(...allFonts);
