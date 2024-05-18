use clap::{arg, Command, ArgAction};
use std::fs::File;
use std::io::{self, Read};
use std::process;

#[derive(Debug)]
struct Options {
    bpp: u8,
    verbose: bool,
    src_filename: String,
    dst_filename: String,
}

fn main() -> io::Result<()> {
    let matches = Command::new("bmp_to_raw")
        .version("0.2.0")
        .author("Oleg Tsymblyuk <aberrant.hacker@gmail.com>")
        .about("Transforms 8bpp .bmp file into raw bitplanes data for the Elektronika MS 0511\n".to_owned() +
               "Only first 1, 2 or 3 bits of color index are used")
        .args(&[
            arg!(bpp: -b --bpp <N> "Resulting number of bits per pixel, default is 2").num_args(1),
            arg!(verbose: -v --verbose "Sets the level of verbosity").action(ArgAction::SetTrue).default_value("false"),
            arg!(<SRC> "Source file to process").required(true).index(1),
            arg!(<DST> "Output file").required(true).index(2),
        ])
        .get_matches();

    let options = Options {
        bpp: *matches.get_one::<u8>("bpp").unwrap_or(&2),
        verbose: matches.get_flag("verbose"),
        src_filename: matches.get_one::<String>("SRC").unwrap().to_string(),
        dst_filename: matches.get_one::<String>("DST").unwrap().to_string(),
    };

    if options.verbose { println!("{:?}", options); }

    let mut file = File::open(&options.src_filename)?;
    let mut bmp = Vec::new();
    file.read_to_end(&mut bmp)?;

    let signature = &bmp[0..2];
    let pixel_array_offset = u32::from_le_bytes([bmp[0x0A], bmp[0x0B], bmp[0x0C], bmp[0x0D]]);
    let image_width        = u32::from_le_bytes([bmp[0x12], bmp[0x13], bmp[0x14], bmp[0x15]]);
    let _image_height      = u32::from_le_bytes([bmp[0x16], bmp[0x17], bmp[0x18], bmp[0x19]]);
    let planes             = u16::from_le_bytes([bmp[0x1A], bmp[0x1B]]);
    let bits_per_pixel     = u16::from_le_bytes([bmp[0x1C], bmp[0x1D]]);
    let compression        = u32::from_le_bytes([bmp[0x1E], bmp[0x1F], bmp[0x20], bmp[0x21]]);
    let image_size         = u32::from_le_bytes([bmp[0x22], bmp[0x23], bmp[0x24], bmp[0x25]]);

    if signature != b"BM" {
        eprintln!("{} : Unknown file type.", options.src_filename);
        process::exit(1);
    }
    if planes != 1 {
        eprintln!("{} : Number of color planes other than 1 is not supported.", options.src_filename);
        process::exit(1);
    }
    if !matches!(bits_per_pixel, 4 | 8) {
        eprintln!("{} : {} bits per pixel not supported, 4 or 8 bits only.", options.src_filename, bits_per_pixel);
        process::exit(1);
    }
    if bits_per_pixel < options.bpp as u16 {
        eprintln!(
            "{} has {}bpp, which is less than resulting {}bpp.",
            options.src_filename, bits_per_pixel, options.bpp
        );
        process::exit(1);
    }
    if compression != 0 {
        eprintln!("{} : Compression is not supported.", options.src_filename);
        process::exit(1);
    }
    if image_width % 8 != 0 {
        println!(
            "{} \x1B[31;1mWARNING\x1B[0m: Image width {} is not multiple of 8",
            options.src_filename, image_width
        );
    }

    let row_width = (bits_per_pixel as u32 * image_width / 8) as usize;
    let row_width_with_padding = ((bits_per_pixel as u32 * image_width + 31) / 32 * 4) as usize;

    let bitmap = &bmp[pixel_array_offset as usize..(pixel_array_offset + image_size) as usize];

    let mut dst_bitmap = Vec::new();
    let mut bit_number = 0;
    let mut bp0_byte = 0u8;
    let mut bp1_byte = 0u8;
    let mut bp2_byte = 0u8;

    let push_byte = match options.bpp {
        1 => |dst: &mut Vec<u8>, bp0_byte: u8, _bp1_byte: u8, _bp2_byte: u8| {
            dst.push(bp0_byte);
        },
        2 => |dst: &mut Vec<u8>, bp0_byte: u8, bp1_byte: u8, _bp2_byte: u8| {
            dst.push(bp0_byte);
            dst.push(bp1_byte);
        },
        3 => |dst: &mut Vec<u8>, bp0_byte: u8, bp1_byte: u8, bp2_byte: u8| {
            dst.push(bp0_byte);
            dst.push(bp1_byte);
            dst.push(bp2_byte);
        },
        _ => unreachable!(),
    };

    if bits_per_pixel == 8 {
        for row_idx in (0..bitmap.len()).step_by(row_width_with_padding).rev() {
            for col_idx in 0..row_width {
                let bitmap_byte = bitmap[row_idx + col_idx];

                bp0_byte |= (bitmap_byte >> 0 & 1) << bit_number;
                bp1_byte |= (bitmap_byte >> 1 & 1) << bit_number;
                bp2_byte |= (bitmap_byte >> 2 & 1) << bit_number;

                bit_number += 1;
                if bit_number < 8 { continue; }

                push_byte(&mut dst_bitmap, bp0_byte, bp1_byte, bp2_byte);
                bit_number = 0;
                bp0_byte = 0;
                bp1_byte = 0;
                bp2_byte = 0;
            }
        }
    } else if bits_per_pixel == 4 {
        for row_idx in (0..bitmap.len()).step_by(row_width_with_padding).rev() {
            for col_idx in 0..row_width {
                let bitmap_byte = bitmap[row_idx + col_idx];

                bp0_byte |= (bitmap_byte >> 4 & 1) << bit_number;
                bp1_byte |= (bitmap_byte >> 5 & 1) << bit_number;
                bp2_byte |= (bitmap_byte >> 6 & 1) << bit_number;

                bit_number += 1;

                // Process the second nibble
                bp0_byte |= (bitmap_byte >> 0 & 1) << bit_number;
                bp1_byte |= (bitmap_byte >> 1 & 1) << bit_number;
                bp2_byte |= (bitmap_byte >> 2 & 1) << bit_number;

                bit_number += 1;
                if bit_number < 8 { continue; }

                push_byte(&mut dst_bitmap, bp0_byte, bp1_byte, bp2_byte);
                bit_number = 0;
                bp0_byte = 0;
                bp1_byte = 0;
                bp2_byte = 0;
            }
        }
    }

    // Write the result to the destination file
    std::fs::write(&options.dst_filename, dst_bitmap)?;

    Ok(())
}
