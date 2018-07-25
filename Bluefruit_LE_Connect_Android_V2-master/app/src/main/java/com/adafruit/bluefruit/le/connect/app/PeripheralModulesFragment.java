package com.adafruit.bluefruit.le.connect.app;

import android.content.Context;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentActivity;
import android.support.v4.content.ContextCompat;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.util.Log;
import android.view.LayoutInflater;

import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;

import com.adafruit.bluefruit.le.connect.R;
import com.adafruit.bluefruit.le.connect.ble.central.BlePeripheral;
import com.adafruit.bluefruit.le.connect.ble.central.BlePeripheralBattery;
import com.adafruit.bluefruit.le.connect.ble.central.BleScanner;
import com.adafruit.bluefruit.le.connect.style.RssiUI;
import com.adafruit.bluefruit.le.connect.utils.LocalizationManager;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class PeripheralModulesFragment extends ConnectedPeripheralFragment {
    // Log
    private final static String TAG = PeripheralModulesFragment.class.getSimpleName();

    // Fragment parameters
    public final static int CONNECTIONMODE_SINGLEPERIPHERAL = 0;
    public final static int CONNECTIONMODE_MULTIPLEPERIPHERAL = 1;

    // Constants
    private final static int MODULE_UART = 1;
//    private final static int MODULE_PLOTTER = 2;
//    private final static int MODULE_PINIO = 3;
//    private final static int MODULE_CONTROLLER = 4;
//    private final static int MODULE_NEOPIXEL = 5;
//    private final static int MODULE_CALIBRATION = 6;
//    private final static int MODULE_THERMALCAMERA = 7;
    private final static int MODULE_DFU = 8;

    // Data
    private PeripheralModulesFragmentListener mListener;
    private List<BlePeripheralBattery> mBatteryPeripherals = new ArrayList<>();

    // region Fragment Lifecycle
    public static PeripheralModulesFragment newInstance(@Nullable String singlePeripheralIdentifier) {      // if singlePeripheralIdentifier is null, uses multiconnect
        PeripheralModulesFragment fragment = new PeripheralModulesFragment();
        fragment.setArguments(createFragmentArgs(singlePeripheralIdentifier));
        return fragment;
    }

    public PeripheralModulesFragment() {
        // Required empty public constructor
    }

    @Override
    public void onAttach(Context context) {
        super.onAttach(context);

        // This makes sure that the container activity has implemented
        // the callback interface. If not, it throws an exception
        try {
            mListener = (PeripheralModulesFragmentListener) context;
        } catch (ClassCastException e) {
            throw new ClassCastException(context.toString() + " must implement PeripheralModulesFragmentListener");
        }
    }

    @Override
    public void onDetach() {
        super.onDetach();
    }

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        // Inflate the layout for this fragment
        return inflater.inflate(R.layout.fragment_peripheralmodules, container, false);
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);

        // Update ActionBar
        setActionBarTitle(R.string.peripheralmodules_title);

        final Context context = getContext();
        if (context != null) {
            // Peripherals recycler view
            RecyclerView recyclerView = view.findViewById(R.id.recyclerView);
            DividerItemDecoration itemDecoration = new DividerItemDecoration(context, DividerItemDecoration.VERTICAL);
            Drawable lineSeparatorDrawable = ContextCompat.getDrawable(context, R.drawable.simpledivideritemdecoration);
            assert lineSeparatorDrawable != null;
            itemDecoration.setDrawable(lineSeparatorDrawable);
            recyclerView.addItemDecoration(itemDecoration);

            recyclerView.setHasFixedSize(false);
            RecyclerView.LayoutManager mPeripheralsLayoutManager = new LinearLayoutManager(getContext());
            recyclerView.setLayoutManager(mPeripheralsLayoutManager);

            // Setup
            mBatteryPeripherals.clear();
            if (mBlePeripheral != null) {   // Single peripheral
                setupBatteryUI(mBlePeripheral);
            } else {       // Multiple peripherals

                List<BlePeripheral> connectedPeripherals = BleScanner.getInstance().getConnectedPeripherals();
                for (BlePeripheral blePeripheral : connectedPeripherals) {
                    setupBatteryUI(blePeripheral);
                }
            }

            WeakReference<PeripheralModulesFragment> weakFragment = new WeakReference<>(this);
            ModulesAdapter adapter = new ModulesAdapter(context, mBatteryPeripherals, mBlePeripheral, view1 -> {
                PeripheralModulesFragment fragment = weakFragment.get();
                if (fragment != null) {
                    final int moduleId = (int) view1.getTag();
                    fragment.onModuleSelected(moduleId);
                }
            });
            recyclerView.setAdapter(adapter);
        }

        FragmentActivity activity = getActivity();
        if (activity != null) {
            activity.invalidateOptionsMenu();        // update options menu with current values
        }
    }

    // endregion

    // region Battery
    private void setupBatteryUI(@NonNull BlePeripheral blePeripheral) {
        final boolean hasBattery = BlePeripheralBattery.hasBattery(blePeripheral);

        if (hasBattery) {
            BlePeripheralBattery blePeripheralBattery = new BlePeripheralBattery(blePeripheral);
            mBatteryPeripherals.add(blePeripheralBattery);
        }
    }
    // endregion

    // region Actions

    private void onModuleSelected(int moduleId) {
        // Go to peripheral modules
        Fragment fragment = null;
        final String singlePeripheralIdentifier = mBlePeripheral != null ? mBlePeripheral.getIdentifier() : null;

        fragment = UartModeFragment.newInstance(singlePeripheralIdentifier);


        if (fragment != null && mListener != null) {
            mListener.startModuleFragment(fragment);
        } else {
            Log.w(TAG, "onModuleSelected null fragment");
        }
    }
    // endregion


    // region Listeners
    interface PeripheralModulesFragmentListener {
        void startModuleFragment(Fragment fragment);
    }

    // endregion

    // region Adapter
    private static class ModulesAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {
        // Constants
        private static final int kCellType_SectionTitle = 0;
        private static final int kCellType_PeripheralDetails = 1;
        private static final int kCellType_Module = 2;

        private static final int kPeripheralDetailsCellsStartPosition = 1;

        // Data
        private Context mContext;
        private List<BlePeripheralBattery> mBatteryPeripherals;
        private int mConnectionMode;
        private List<BlePeripheral> mConnectedPeripherals;
        private BlePeripheral mBlePeripheral;
        private View.OnClickListener mOnClickListener;

        ModulesAdapter(@NonNull Context context, @NonNull List<BlePeripheralBattery> batteryPeripherals, @Nullable BlePeripheral blePeripheralForSingleConnectionMode, @NonNull View.OnClickListener onClickListener) {
            mContext = context.getApplicationContext();
            mBatteryPeripherals = batteryPeripherals;
            mConnectionMode = blePeripheralForSingleConnectionMode == null ? CONNECTIONMODE_MULTIPLEPERIPHERAL : CONNECTIONMODE_SINGLEPERIPHERAL;
            mBlePeripheral = blePeripheralForSingleConnectionMode;
            mOnClickListener = onClickListener;
        }

        private int getModuleCellsStartPosition() {
            return kPeripheralDetailsCellsStartPosition + mConnectedPeripherals.size() + 1;  // +1 because Modules header
        }

        @Override
        public int getItemViewType(int position) {
            super.getItemViewType(position);

            final int kModulesSectionTitlePosition = getModuleCellsStartPosition() - 1;
            if (position == kPeripheralDetailsCellsStartPosition - 1 || position == kModulesSectionTitlePosition) {
                return kCellType_SectionTitle;
            } else if (position < kModulesSectionTitlePosition) {
                return kCellType_PeripheralDetails;
            } else {
                return kCellType_Module;
            }
        }

        // Create new views (invoked by the layout manager)
        @NonNull
        @Override
        public RecyclerView.ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
            //Log.d(TAG, "onCreateViewHolder type: " + viewType);
            switch (viewType) {
                case kCellType_SectionTitle: {
                    View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.layout_common_section_item, parent, false);
                    return new SectionViewHolder(view);
                }
                case kCellType_PeripheralDetails: {
                    View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.layout_peripheralmodules_peripheraldetails, parent, false);
                    return new PeripheralDetailsViewHolder(view);
                }
                case kCellType_Module: {
                    View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.layout_peripheralmodules_module, parent, false);
                    return new ModuleViewHolder(view);
                }
                default: {
                    Log.e(TAG, "Unknown cell type");
                    throw new AssertionError("Unknown cell type");
                }
            }
        }

        // Replace the contents of a view (invoked by the layout manager)
        @Override
        public void onBindViewHolder(@NonNull final RecyclerView.ViewHolder holder, int position) {

            LocalizationManager localizationManager = LocalizationManager.getInstance();
            final int viewType = getItemViewType(position);
            switch (viewType) {
                case kCellType_SectionTitle: {
                    String stringId;
                    if (position == kPeripheralDetailsCellsStartPosition - 1) {
                        stringId = isInMultiUartMode() ? "peripheralmodules_sectiontitle_device_multiconnect" : "peripheralmodules_sectiontitle_device_single";
                    } else {
                        stringId = "peripheralmodules_sectiontitle_modules";
                    }

                    SectionViewHolder sectionViewHolder = (SectionViewHolder) holder;
                    sectionViewHolder.titleTextView.setText(localizationManager.getString(mContext, stringId));
                    break;
                }

                case kCellType_PeripheralDetails: {
                    final int detailsIndex = position - kPeripheralDetailsCellsStartPosition;
                    BlePeripheral blePeripheral = mConnectedPeripherals.get(detailsIndex);

                    String name = blePeripheral.getName();
                    if (name == null) {
                        name = mContext.getString(R.string.scanner_unnamed);
                    }

                    PeripheralDetailsViewHolder detailsViewHolder = (PeripheralDetailsViewHolder) holder;
                    detailsViewHolder.nameTextView.setText(name);
                    final int rssi = blePeripheral.getRssi();
                    detailsViewHolder.rssiImageView.setImageResource(RssiUI.getDrawableIdForRssi(rssi));
                    detailsViewHolder.rssiTextView.setText(String.format(Locale.ENGLISH, mContext.getString(R.string.peripheralmodules_rssi_format), rssi));

                    BlePeripheralBattery blePeripheralBattery = getPeripheralBatteryForPeripheral(blePeripheral);
                    final boolean hasBattery = blePeripheralBattery != null;
                    detailsViewHolder.batteryGroupView.setVisibility(hasBattery ? View.VISIBLE : View.GONE);
                    if (hasBattery) {
                        final int batteryLevel = blePeripheralBattery.getCurrentBatteryLevel();
                        final String batteryPercentage = String.format(mContext.getString(R.string.peripheralmodules_battery_format), batteryLevel);
                        detailsViewHolder.batteryTextView.setText(batteryPercentage);
                    }

                    break;
                }

                case kCellType_Module: {
                    final int moduleIndex = position - getModuleCellsStartPosition();
                    //final int moduleId = getMenuItems()[moduleIndex];

                    int iconDrawableId = 0;
                    int titleId = 0;



                    iconDrawableId = R.drawable.tab_uart_icon;
                    titleId = R.string.uart_tab_title;

                    ModuleViewHolder moduleViewHolder = (ModuleViewHolder) holder;
                    if (iconDrawableId != 0) {
                        moduleViewHolder.iconImageView.setImageResource(iconDrawableId);
                    }
                    if (titleId != 0) {
                        moduleViewHolder.nameTextView.setText(titleId);
                    }

                    moduleViewHolder.mainViewGroup.setTag(MODULE_UART);
                    moduleViewHolder.mainViewGroup.setOnClickListener(view -> mOnClickListener.onClick(view));
                    break;
                }
            }
        }

        @SuppressWarnings("UnnecessaryLocalVariable")
        @Override
        public int getItemCount() {
            final int kNumSections = 2;
            mConnectedPeripherals = BleScanner.getInstance().getConnectedPeripherals();
            final int numItems = 4;

            //Log.d(TAG, "menuitems: "+getMenuItems().length);
            return numItems;
        }

        private boolean isInMultiUartMode() {
            return mConnectionMode == CONNECTIONMODE_MULTIPLEPERIPHERAL && mConnectedPeripherals.size() > 0;
        }


        class SectionViewHolder extends RecyclerView.ViewHolder {
            TextView titleTextView;

            SectionViewHolder(View view) {
                super(view);
                titleTextView = view.findViewById(R.id.titleTextView);
            }
        }

        class PeripheralDetailsViewHolder extends RecyclerView.ViewHolder {
            TextView nameTextView;
            ImageView rssiImageView;
            TextView rssiTextView;
            ViewGroup batteryGroupView;
            TextView batteryTextView;

            PeripheralDetailsViewHolder(View view) {
                super(view);
                nameTextView = view.findViewById(R.id.nameTextView);
                rssiImageView = view.findViewById(R.id.rssiImageView);
                rssiTextView = view.findViewById(R.id.rssiTextView);
                batteryGroupView = view.findViewById(R.id.batteryGroupView);
                batteryTextView = view.findViewById(R.id.batteryTextView);
            }
        }

        class ModuleViewHolder extends RecyclerView.ViewHolder {
            ViewGroup mainViewGroup;
            ImageView iconImageView;
            TextView nameTextView;

            ModuleViewHolder(View view) {
                super(view);
                mainViewGroup = view.findViewById(R.id.mainViewGroup);
                mainViewGroup.setClickable(true);
                iconImageView = view.findViewById(R.id.iconImageView);
                nameTextView = view.findViewById(R.id.nameTextView);
            }
        }

        private @Nullable
        BlePeripheralBattery getPeripheralBatteryForPeripheral(@NonNull BlePeripheral blePeripheral) {
            String identifier = blePeripheral.getIdentifier();
            BlePeripheralBattery result = null;

            boolean found = false;
            int i = 0;
            while (!found && i < mBatteryPeripherals.size()) {
                BlePeripheralBattery blePeripheralBattery = mBatteryPeripherals.get(i);
                if (blePeripheralBattery.getIdentifier().equals(identifier)) {
                    found = true;
                    result = blePeripheralBattery;
                }
                i++;
            }

            return result;
        }
    }

    // endregion
}
