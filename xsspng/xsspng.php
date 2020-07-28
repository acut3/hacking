<?php ob_start("png");

$width = 75;
$height = 75;

# pack():
#   N = 4 bytes, big-endian

function crc($x) {
    return pack('N', crc32($x));
}

function chunk($name, $data) {
    $x = $name . $data;
    return pack('N', strlen($data)) . $x . crc($x);
}

function idat($data, $width, $height) {
    $row_bytes = 3 * $width;
    $img_bytes = $row_bytes * $height;
    # Pad/crop script to desired dimensions
    if (strlen($data) < $img_bytes) {
        $data = str_pad($data, $img_bytes, "\0");
    } else {
        $data = substr($data, 0, $img_bytes);
    }
    # Filtering phase (using filter 0 which does nothing)
    $filtered = '';
    for ($i = 0; $i < $height; $i++) {
        $filtered .= "\0" . substr($data, $i*$row_bytes, $row_bytes);
    }
    # Compression phase (no compresion)
    $compressed = zlib_encode($filtered, ZLIB_ENCODING_DEFLATE, 0);
    return $compressed;
}

function png($data) {
    global $width, $height;

    # PNG file signature
    $png = "\x89PNG\x0d\x0a\x1a\x0a";

    # IHDR
    $ihdr  = pack('N', $width);
    $ihdr .= pack('N', $height);
    $ihdr .= "\x08";     # bit depth
    $ihdr .= "\x02";     # color type: RGB
    $ihdr .= "\x00";     # compression method
    $ihdr .= "\x00";     # filter method
    $ihdr .= "\x00";     # interlace method: no interlace
    $png .= chunk('IHDR', $ihdr);

    # IDAT
    $idat = idat($data, $width, $height);
    $png .= chunk('IDAT', $idat);

    # IEND
    $png .= chunk('IEND', '');

    return $png;
}
?>
Can you read me?
<?php 
header('Content-Type: image/png');
ob_end_flush();
?>
