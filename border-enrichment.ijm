// William Giang
// 2025-05-28
//
// Assumes the input directory contains a series of tifs with stored ROIs as overlays
// The order is assumed to be background, border, non-border of cell 1, non-border of cell2
//
// Update(s): 
// 2025-03-21
//  - explicitly Set Measurements
// 	- now includes more measurements of the ROIs for better quality assurance.
// 2025-05-28
//  - able to change ROI line width (but also now guarantees same line width)

#@ File    (label = "Input directory", style = "directory") input
#@ File    (label = "Output directory for CSV", style = "directory") output_dir_csv
#@ String  (label = "Output CSV file suffix", value = "border-enrichment_") table_name
#@ Integer (label = "Width of drawn line", value=10) ROI_linewidth
#@ String (label = "Image File suffix", value = ".tif") suffix


// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output_dir_csv, list[i]);
	}
}

function getTypeOfROI(x, ROI_types_arr) {
	// the order of the ROIs determines what they are.
	// 1. background
	// 2. border
	// 3. non-border in cell 1
	// 4. non-border in cell 2
	//
	// use the modulo operator to figure this out
	// 0 % 4 = 0
	// 1 % 4 = 1
	// 2 % 4 = 2
	// 3 % 4 = 3

	return ROI_types_arr[x % ROI_types_arr.length];
}

function processFile(input, output_dir_csv, file) {
	// Make sure the ROI Manager is open and reset
	roiManager("reset");
	
	print("Processing: " + input + File.separator + file);
	open(input + File.separator + file);
	
	file_name = File.nameWithoutExtension;
	
	getDimensions(width, height, channels, slices, frames);
	
	run("To ROI Manager");
	
	if (RoiManager.size % ROI_types_arr.length != 0) exit("expected the number of ROIs to be divisible by 4");

	for (i = 0; i < RoiManager.size; i++) {
		ROI_type = getTypeOfROI(i, ROI_types_arr);
		roiManager("Select", i);
		roiManager("Set Line Width", ROI_linewidth);
		table1_row_to_write = MeasureROIsAndUpdateTable(table_name, ROI_type, table1_row_to_write, i);
	}
	close(file);
}

function MeasureROIsAndUpdateTable(table, ROI_name, main_row_to_write, ROI_index) {

	row_to_write = main_row_to_write;
	
	// achieve integer division with Math.floor
	ROI_ID = IJ.pad(Math.floor((ROI_index / 4))+1, 2);
	Table.set("ROI_ID", row_to_write, ROI_ID, table);
	
	for (c = 1; c <= channels; c++) {
		Stack.setChannel(c);
		run("Measure");
		
		Mean_int     = getResult("Mean",   c-1);
		Area         = getResult("Area",   c-1);
		Percent_Area = getResult("%Area",  c-1);
		Length       = getResult("Length", c-1);
		
		Table.set("Filename"                      , row_to_write, file_name, table);
		Table.set("C"+c + "_MeanInt_"  + ROI_name , row_to_write, Mean_int , table);
		Table.set("C"+c+"_Area_" + ROI_name,        row_to_write, Area     , table);
		Table.set("C"+c+"_PercentArea_" + ROI_name, row_to_write, Percent_Area, table);
		Table.set("C"+c+"_Length_"      + ROI_name, row_to_write, Length   , table);
		Table.update;
	}
	close("Results");
	
	// Keep the measurements for different channels on the same row
	if ((ROI_index > 0 ) && ((ROI_index +1) % ROI_types_arr.length == 0)) {
		row_to_write += 1;
	}
	
	return row_to_write;
}
run("Set Measurements...", "area mean min shape integrated area_fraction stack display redirect=None decimal=3");
setBatchMode(true);
Table.create(table_name);
var table1_row_to_write = 0;
ROI_types_arr = newArray("background", "border", "non-border_cell1", "non-border_cell2");

processFolder(input);
selectWindow(table_name);
Table.showRowIndexes(true);
saveAs("Results", output_dir_csv + File.separator + table_name + ".csv");
close(table_name);
run("Close All");
roiManager("reset");
setBatchMode(false);
print("Done");
